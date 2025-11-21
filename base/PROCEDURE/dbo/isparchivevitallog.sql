SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc : ispArchiveVitalLog                                     */
/* Creation Date: 17-Aug-2005                                           */
/* Copyright: IDS                                                       */
/* Written by: MaryVong                                                 */
/*                                                                      */
/* Purpose: Housekeeping VitalLog table                                 */
/*				Note: Duplicate from ispArchiveVitalLog3						   */
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
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/************************************************************************/

CREATE  PROC  [dbo].[ispArchiveVitalLog]
@c_archivekey  NVARCHAR(10)             
,              @b_Success      int        OUTPUT    
,              @n_err          int        OUTPUT    
,              @c_errmsg       NVARCHAR(250)  OUTPUT    
AS
BEGIN  
   SET NOCOUNT ON			-- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF	
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF    

	DECLARE @dummy	 NVARCHAR(1),
	   @n_continue 	int,  
	   @n_starttcnt	int, -- Holds the current transaction count
	   @n_cnt 			int, -- Holds @@ROWCOUNT after certain operations
	   @b_debug 		int -- Debug On OR Off

	/* #INCLUDE <SPACC1.SQL> */     
	DECLARE @n_retain_days 		int, -- days to hold data
	   @d_result  					datetime, -- date (GETDATE() - noofdaystoretain)
	   @c_datetype 			 NVARCHAR(10), -- 1=EditDate, 2=AddDate
	   @n_archive_TL_records	int -- No. of VitalLog records to be archived

	DECLARE @local_n_err int,
	   @local_c_errmsg NVARCHAR(254)

	DECLARE @c_TransmitFlag 	 NVARCHAR(2),
	   @n_TLStart 					 NVARCHAR(15),
	   @n_TLend 					 NVARCHAR(15),
	   @c_whereclause 			 NVARCHAR(254),
	   @c_temp 						 NVARCHAR(254),
	   @c_CopyRowsToArchiveDatabase NVARCHAR(1),
	   @c_copyfrom_db 			 NVARCHAR(30),
	   @c_copyto_db 				 NVARCHAR(30),
		@c_VitalLogKey 		 NVARCHAR(10),
	   @d_today 						datetime

	SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",
	   @b_debug = 0, @local_n_err = 0, @local_c_errmsg = ' '

	SELECT @n_archive_TL_records = 0

   SELECT @c_copyfrom_db = livedatabasename,
		@c_copyto_db = archivedatabasename,
		@n_retain_days = tranmlognumberofdaystoretain,
		@c_datetype = tranmlogdatetype,
		@n_TLStart= ISNULL (tranmlogstart,0),
		@n_TLend= ISNULL (tranmlogend, 9999999999),  -- End value for transmitlog
		@c_CopyRowsToArchiveDatabase = copyrowstoarchivedatabase
   FROM ArchiveParameters (NOLOCK)
   WHERE archivekey = @c_archivekey

	IF db_id(@c_copyto_db) IS NULL
	BEGIN
	   SELECT @n_continue = 3
	   SELECT @local_n_err = 77100
	   SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
	   SELECT @local_c_errmsg =
	   ": Target Database " + @c_copyto_db + " Does NOT exist " + " ( " +
	   " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")" +' (ispArchiveVitalLog) '
	END

	IF (@n_continue = 1 OR @n_continue = 2)
	BEGIN
		SELECT @c_TransmitFlag = '9' -- default only archive those transmitflag = '9' 

	   SELECT @d_today = CONVERT(datetime,CONVERT(char(11),GETDATE(),106))
	   SELECT @d_result = DATEADD(DAY,(-@n_retain_days),@d_today)
	   SELECT @d_result = DATEADD(DAY,1,@d_result)
	END

	IF (@b_debug = 1)
	BEGIN
      SELECT '@d_result', @d_result
   END
   
	IF (@n_continue = 1 OR @n_continue = 2)
	BEGIN
	   SELECT @b_success = 1
	   SELECT @c_temp = "Archive Of IDS VitalLog Started with Parms; Datetype = " + dbo.fnc_RTrim(@c_datetype) +
	   ' ; TransmitFlag = '+ dbo.fnc_RTrim(@c_TransmitFlag)+ ' ; VitalLogKey = '+@n_TLStart+'-'+@n_TLend+
	   ' ; Copy Rows to Archive = '+dbo.fnc_RTrim(@c_CopyRowsToArchiveDatabase)+ ' ; Retain Days = '+ CONVERT(char(6),@n_retain_days)
	   EXECUTE nspLogAlert
	   @c_ModuleName   = "ispArchiveVitalLog",
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

	IF  (@n_continue = 1 OR @n_continue = 2)
	BEGIN
	   IF (@n_TLStart IS NOT NULL AND @n_TLend IS NOT NULL)
	   BEGIN
	      SELECT @c_temp =  ' AND VitalLog.VitalLogKey BETWEEN ' +  @n_TLStart  + ' AND '+ @n_TLend
	   END

	   IF ((@n_continue = 1 OR @n_continue = 2) AND @c_CopyRowsToArchiveDatabase = 'Y')
	   BEGIN 
	      SELECT @b_success = 1
	      EXEC nsp_BUILD_ARCHIVE_TABLE @c_copyfrom_db, @c_copyto_db, 'VitalLog',@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
	      IF NOT @b_success = 1
      	BEGIN
      		SELECT @dummy 
      		SELECT @n_continue = 3
      	END
		END   

      IF ((@n_continue = 1 OR @n_continue = 2) AND @c_CopyRowsToArchiveDatabase = 'Y')
      BEGIN  
         SELECT @b_success = 1
         EXEC nsp_BUILD_ARCHIVE_TABLE @c_copyfrom_db, @c_copyto_db, 'VitalLog',@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
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

		   EXECUTE nspBuildAlterTableString @c_copyto_db,'VitalLog',@b_success OUTPUT,@n_err OUTPUT, @c_errmsg OUTPUT
		   IF NOT @b_success = 1
	   	BEGIN
	   		SELECT @n_continue = 3
	   	END
		END

	   IF ((@n_continue = 1 OR @n_continue = 2) AND @c_CopyRowsToArchiveDatabase = 'Y')
	   BEGIN
	      IF (@b_debug = 1)
	      BEGIN
	         print "building alter table string for VitalLog..."
	      END
	      EXECUTE nspBuildAlterTableString @c_copyto_db,'VitalLog',@b_success OUTPUT,@n_err OUTPUT, @c_errmsg OUTPUT
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
		         SELECT @c_whereclause = "WHERE VitalLog.EditDate  <= " + '"'+ CONVERT(char(11),@d_result,106)+'"'
                                       + " AND (VitalLog.TRANSMITFLAG = '9' OR VitalLog.TRANSMITFLAG = '5') " +		                                 
		                                 +  @c_temp
		      END
		      IF @c_datetype = "2" -- AddDate
		      BEGIN
		         SELECT @c_whereclause = "WHERE VitalLog.AddDate  <= " + '"'+ CONVERT(char(11),@d_result,106) +'"'
		                                 + " AND (VitalLog.TRANSMITFLAG = '9' OR VitalLog.TRANSMITFLAG = '5') " +		                                 
		                                 +  @c_temp
		      END

				IF (@b_debug = 1)
				BEGIN
				   SELECT '@d_result', @d_result
					SELECT @c_whereclause '@c_whereclause'
				END

	         EXEC (
	         ' DECLARE CUR_VitalLogkey CURSOR FAST_FORWARD READ_ONLY FOR ' + 
	         ' SELECT VitalLogKey FROM VitalLog (NOLOCK) ' + @c_whereclause + 
	         ' ORDER BY VitalLogKey ' ) 
	         
	         OPEN CUR_VitalLogkey 
	         
	         FETCH NEXT FROM CUR_VitalLogkey INTO @c_VitalLogKey
	         
	         WHILE @@fetch_status <> -1
	         BEGIN
	            UPDATE VitalLog WITH (ROWLOCK)
	               SET ArchiveCop = '9' 
	            WHERE VitalLogKey = @c_VitalLogKey  
	
	      		SELECT @local_n_err = @@error, @n_cnt = @@rowcount            
	            SELECT @n_archive_TL_records = @n_archive_TL_records + 1     
	
					IF (@b_debug = 1)
					BEGIN                          
						SELECT @c_VitalLogKey '@c_VitalLogKey',  @n_archive_TL_records '@n_archive_TL_records'
					END

	            IF @local_n_err <> 0
	         	BEGIN 
	               SELECT @n_continue = 3
	               SELECT @local_n_err = 77101
	               SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
	               SELECT @local_c_errmsg =
	               ": Update of Archivecop failed - CC Table. (ispArchiveVitalLog) " + " ( " +
	               " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
					END

					FETCH NEXT FROM CUR_VitalLogkey INTO @c_VitalLogKey
				END -- while VitalLogKey 

	         CLOSE CUR_VitalLogkey
	         DEALLOCATE CUR_VitalLogkey
      	END 

		   IF ((@n_continue = 1 OR @n_continue = 2) AND @c_CopyRowsToArchiveDatabase = 'Y')
		   BEGIN
		      SELECT @c_temp = "Attempting to Archive " + dbo.fnc_RTrim(CONVERT(char(6),@n_archive_TL_records )) +
		      " VitalLog records "
		      EXECUTE nspLogAlert
		      @c_ModuleName   = "ispArchiveVitalLog",
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

			IF (@n_continue = 1 OR @n_continue = 2)
			BEGIN 
			   SELECT @b_success = 1
			   EXEC nsp_BUILD_INSERT   @c_copyto_db, 'VitalLog',1 ,@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
			   IF NOT @b_success = 1
			   BEGIN
			      SELECT @n_continue = 3
			   END
			END
   
		   IF (@b_debug = 1)
		   BEGIN
		      SELECT * FROM VitalLog (NOLOCK)
		      WHERE ArchiveCop = '9'
		   END

-- 		   IF (@n_continue = 1 OR @n_continue = 2)
-- 		   BEGIN  
-- 			   IF (@b_debug = 0)
-- 			   BEGIN
-- 					DECLARE CUR_VitalLogkey CURSOR FAST_FORWARD READ_ONLY FOR
-- 		         SELECT VitalLogKey FROM VitalLog (NOLOCK) 
-- 		         WHERE ArchiveCop = '9'
-- 		         ORDER BY VitalLogKey        
-- 		 
-- 		         OPEN CUR_VitalLogkey 
-- 		         
-- 		         FETCH NEXT FROM CUR_VitalLogkey INTO @c_VitalLogKey
-- 		         
-- 		         WHILE @@fetch_status <> -1
-- 		         BEGIN
-- 		            DELETE VitalLog 
-- 		            WHERE VitalLogKey = @c_VitalLogKey  
-- 		
-- 		      		SELECT @local_n_err = @@error, @n_cnt = @@rowcount
-- 		            
-- 		            FETCH NEXT FROM CUR_VitalLogkey INTO @c_VitalLogKey
-- 		         END -- while VitalLogKey 
-- 		
-- 		         CLOSE CUR_VitalLogkey
-- 		         DEALLOCATE CUR_VitalLogkey
--    			END
-- 
-- 			   IF @local_n_err <> 0
-- 			   BEGIN
-- 			      SELECT @n_continue = 3
-- 			      SELECT @local_n_err = 77104
-- 			      SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
-- 			      SELECT @local_c_errmsg =
-- 			      ":  VitalLog delete failed. (ispArchiveVitalLog) " + " ( " +
-- 			      " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
-- 			   END
-- 			END
--        
-- 			IF @n_continue = 3
-- 			BEGIN
-- 				ROLLBACK TRAN
-- 			END
-- 			ELSE
-- 			BEGIN
-- 				COMMIT TRAN
-- 			END
		END
	END

	IF (@n_continue = 1 OR @n_continue = 2)
	BEGIN
		SELECT @b_success = 1
		EXECUTE nspLogAlert
		@c_ModuleName   = "ispArchiveVitalLog",
		@c_AlertMessage = "Archive Of VitalLog Ended Normally.",
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
			@c_ModuleName   = "ispArchiveVitalLog",
			@c_AlertMessage = "Archive Of VitalLog Ended Abnormally - Check This Log For Additional Messages.",
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
		EXECUTE nsp_logerror @n_err, @c_errmsg, "ispArchiveVitalLog"
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