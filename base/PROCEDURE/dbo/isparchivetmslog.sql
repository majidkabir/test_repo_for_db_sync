SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc : ispArchiveTMSLog                                       */
/* Creation Date: 21-Mar-2008                                           */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: Housekeeping TMSLog table                                   */
/*				Note: Duplicate from ispArchiveTransmitLog3						*/
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
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/************************************************************************/

CREATE PROC  [dbo].[ispArchiveTMSLog]
@c_Archivekey  NVARCHAR(10)             
,              @b_Success      int        OUTPUT    
,              @n_err          int        OUTPUT    
,              @c_errmsg       NVARCHAR(250)  OUTPUT    
AS
BEGIN  
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF 

	DECLARE @dummy		NVARCHAR(1),
	   @n_continue 	int,  
	   @n_starttcnt	int, -- Holds the current transaction count
	   @n_cnt 			int, -- Holds @@ROWCOUNT after certain operations
	   @b_debug 		int -- Debug On OR Off

	/* #INCLUDE <SPACC1.SQL> */     
	DECLARE @n_retain_days 		int, -- days to hold data
	   @d_result  					datetime, -- date (GETDATE() - noofdaystoretain)
	   @c_datetype 				NVARCHAR(10), -- 1=EditDate, 2=AddDate
	   @n_Archive_TL_records	int -- No. of TMSLog records to be Archived

	DECLARE @local_n_err int,
	   @local_c_errmsg	NVARCHAR(254)

	DECLARE @c_TransmitFlag 		   NVARCHAR(2),
	   @c_TLStart 						   NVARCHAR(15),
	   @c_TLEnd 						   NVARCHAR(15),
	   @c_whereclause 				   nvarchar(1000),
	   @c_temp 							   nvarchar(1000),
	   @c_CopyRowsToArchiveDatabase	NVARCHAR(1),
	   @c_Copyfrom_db 				   NVARCHAR(30),
	   @c_CopyTo_DB 					   NVARCHAR(30),
		@n_TMSLogKey 			         int,
	   @d_today 						   datetime

	SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',
	   @b_debug = 0, @local_n_err = 0, @local_c_errmsg = ' '

	SELECT @n_Archive_TL_records = 0

   SELECT @c_Copyfrom_db = livedatabasename,
		@c_CopyTo_DB = Archivedatabasename,
		@n_retain_days = tranmlognumberofdaystoretain,
		@c_datetype = tranmlogdatetype,
		@c_TLStart= ISNULL (tranmlogstart,''),
		@c_TLend= ISNULL (tranmlogend,'ZZZZZZZZZZ'),
		@c_CopyRowsToArchiveDatabase = CopyRowsToArchivedatabase
   FROM ArchiveParameters (NOLOCK)
   WHERE Archivekey = @c_Archivekey

	IF db_id(@c_CopyTo_DB) IS NULL
	BEGIN
	   SELECT @n_continue = 3
	   SELECT @local_n_err = 77100
	   SELECT @local_c_errmsg = CONVERT(NVARCHAR(5),@local_n_err)
	   SELECT @local_c_errmsg =
	   ': Target Database ' + @c_CopyTo_DB + ' Does NOT exist ' + ' ( ' +
	   ' SQLSvr MESSAGE = ' + LTRIM(RTRIM(@local_c_errmsg)) + ')' +' (ispArchiveTMSLog) '
	END

	IF (@n_continue = 1 OR @n_continue = 2)
	BEGIN
		SELECT @c_TransmitFlag = '9' -- default only Archive those transmitflag = '9' 

	   SELECT @d_today = CONVERT(datetime,CONVERT(char(11),GETDATE(),106))
	   SELECT @d_result = DATEADD(DAY,(-@n_retain_days),@d_today)
	   SELECT @d_result = DATEADD(DAY,1,@d_result)
	END

	IF (@n_continue = 1 OR @n_continue = 2)
	BEGIN
	   SELECT @b_success = 1
	   SELECT @c_temp = 'Archive Of IDS TMSLog Started with Parms; Datetype = ' + RTRIM(@c_datetype) +
	   ' ; TransmitFlag = '+ RTRIM(@c_TransmitFlag)+ ' ; TMSLogKey = '+RTRIM(@c_TLStart)+'-'+RTRIM(@c_TLEnd)+
	   ' ; Copy Rows to Archive = '+RTRIM(@c_CopyRowsToArchiveDatabase)+ ' ; Retain Days = '+ CONVERT(NVARCHAR(6),@n_retain_days)
	   EXECUTE nspLogAlert
	   @c_ModuleName   = 'ispArchiveTMSLog',
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
-- 	   IF (RTRIM(@c_TLStart) IS NOT NULL AND RTRIM(@c_TLEnd) IS NOT NULL)
-- 	   BEGIN
-- 	      SELECT @c_temp =  ' AND TMSLog.TMSLogKey BETWEEN '+ ''' + RTRIM(@c_TLStart) + ''' +' AND '+
-- 	            '''+RTRIM(@c_TLEnd)+'''
-- 	   END

	   IF ((@n_continue = 1 OR @n_continue = 2) AND @c_CopyRowsToArchiveDatabase = 'Y')
	   BEGIN 
	      SELECT @b_success = 1
	      EXEC nsp_BUILD_Archive_TABLE @c_Copyfrom_db, @c_CopyTo_DB, 'TMSLog',@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
	      IF NOT @b_success = 1
      	BEGIN
      		SELECT @dummy 
      		SELECT @n_continue = 3
      	END
		END   

      IF ((@n_continue = 1 OR @n_continue = 2) AND @c_CopyRowsToArchiveDatabase = 'Y')
      BEGIN  
         SELECT @b_success = 1
         EXEC nsp_BUILD_Archive_TABLE @c_Copyfrom_db, @c_CopyTo_DB, 'TMSLog',@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
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

		   EXECUTE nspBuildAlterTableString @c_CopyTo_DB,'TMSLog',@b_success OUTPUT,@n_err OUTPUT, @c_errmsg OUTPUT
		   IF NOT @b_success = 1
	   	BEGIN
	   		SELECT @n_continue = 3
	   	END
		END

	   IF ((@n_continue = 1 OR @n_continue = 2) AND @c_CopyRowsToArchiveDatabase = 'Y')
	   BEGIN
	      IF (@b_debug = 1)
	      BEGIN
	         print 'building alter table string for TMSLog...'
	      END
	      EXECUTE nspBuildAlterTableString @c_CopyTo_DB,'TMSLog',@b_success OUTPUT,@n_err OUTPUT, @c_errmsg OUTPUT
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
		      IF @c_datetype = '1' -- EditDate
		      BEGIN
		         SELECT @c_whereclause = 'WHERE TMSLog.EditDate  <= ' + ''''+ CONVERT(char(11),@d_result,106)+''''
                                       + ' AND (TMSLog.TRANSMITFLAG = ''9'' OR TMSLog.TRANSMITFLAG = ''5'') ' 
		      END
		      IF @c_datetype = '2' -- AddDate
		      BEGIN
		         SELECT @c_whereclause = 'WHERE TMSLog.AddDate  <= ' + ''''+ CONVERT(char(11),@d_result,106) +''''
		                                 + ' AND (TMSLog.TRANSMITFLAG = ''9'' OR TMSLog.TRANSMITFLAG = ''5'') ' +		                                 
		                                 +  @c_temp
		      END

				IF (@b_debug = 1)
				BEGIN
					SELECT @c_whereclause '@c_whereclause'
				END

	         EXEC (
	         ' DECLARE CUR_TMSLogKey CURSOR FAST_FORWARD READ_ONLY FOR ' + 
	         ' SELECT TMSLogKey FROM TMSLog (NOLOCK) ' + @c_whereclause + 
	         ' ORDER BY TMSLogKey ' ) 
	         
	         OPEN CUR_TMSLogKey 
	         
	         FETCH NEXT FROM CUR_TMSLogKey INTO @n_TMSLogKey
	         
	         WHILE @@fetch_status <> -1
	         BEGIN
	            UPDATE TMSLog WITH (ROWLOCK)
	               SET ArchiveCop = '9' 
	            WHERE TMSLogKey = @n_TMSLogKey  
	
	      		SELECT @local_n_err = @@error, @n_cnt = @@rowcount            
	            SELECT @n_Archive_TL_records = @n_Archive_TL_records + 1     
	
					IF (@b_debug = 1)
					BEGIN                          
						SELECT @n_TMSLogKey '@n_TMSLogKey',  @n_Archive_TL_records '@n_Archive_TL_records'
					END

	            IF @local_n_err <> 0
	         	BEGIN 
	               SELECT @n_continue = 3
	               SELECT @local_n_err = 77101
	               SELECT @local_c_errmsg = CONVERT(NVARCHAR(5),@local_n_err)
	               SELECT @local_c_errmsg =
	               ': Update of Archivecop failed - CC Table. (ispArchiveTMSLog) ' + ' ( ' +
	               ' SQLSvr MESSAGE = ' + LTRIM(RTRIM(@local_c_errmsg)) + ')'
					END

					FETCH NEXT FROM CUR_TMSLogKey INTO @n_TMSLogKey
				END -- while TMSLogKey 

	         CLOSE CUR_TMSLogKey
	         DEALLOCATE CUR_TMSLogKey
      	END 

		   IF ((@n_continue = 1 OR @n_continue = 2) AND @c_CopyRowsToArchiveDatabase = 'Y')
		   BEGIN
		      SELECT @c_temp = 'Attempting to Archive ' + RTRIM(CONVERT(NVARCHAR(6),@n_Archive_TL_records )) +
		      ' TMSLog records '
		      EXECUTE nspLogAlert
		      @c_ModuleName   = 'ispArchiveTMSLog',
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
			   EXEC nsp_BUILD_INSERT   @c_CopyTo_DB, 'TMSLog',1 ,@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
			   IF NOT @b_success = 1
			   BEGIN
			      SELECT @n_continue = 3
			   END
			END
   
		   IF (@b_debug = 1)
		   BEGIN
		      SELECT * FROM TMSLog (NOLOCK)
		      WHERE ArchiveCop = '9'
		   END
		END
	END

	IF (@n_continue = 1 OR @n_continue = 2)
	BEGIN
		SELECT @b_success = 1
		EXECUTE nspLogAlert
		@c_ModuleName   = 'ispArchiveTMSLog',
		@c_AlertMessage = 'Archive Of TMSLog Ended Normally.',
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
			@c_ModuleName   = 'ispArchiveTMSLog',
			@c_AlertMessage = 'Archive Of TMSLog Ended Abnormally - Check This Log For Additional Messages.',
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
		EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispArchiveTMSLog'
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