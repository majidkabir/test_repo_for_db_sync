SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc : isp_ArchiveWave                                        */
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
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data ModIFications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 2005-Aug-09  Shong		   Performance Tuning                        */
/* 2007-Feb-02  Shong         Bug Fixing                                */
/* 2008-Nov-24  Leong         SOS121711 - archive WaveDetail then Wave  */
/************************************************************************/

CREATE PROC [dbo].[isp_ArchiveWave]
		@c_copyfrom_db  NVARCHAR(55),
		@c_copyto_db    NVARCHAR(55),
		@copyrowstoarchivedatabase NVARCHAR(1),
		@b_success int output    
AS
/*--------------------------------------------------------------*/
-- THIS ARCHIVE SCRIPT IS EXECUTED FROM nsparchiveshippingorder
/*--------------------------------------------------------------*/
BEGIN -- main
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

	DECLARE @n_continue     int    ,  
			@n_starttcnt    int    , -- holds the current TRANsaction count
			@n_cnt          int    , -- holds @@rowcount after certain operations
			@b_debug        int      -- debug on or off
	     
	/* #include <sparpo1.sql> */     
	DECLARE
		@n_archive_Wave_records	        int, -- # of Wave records to be archived
		@n_archive_Wave_detail_records	int, -- # of WaveDetail records to be archived
		@n_err                          int,
		@c_errmsg                       NVARCHAR(254),
		@local_n_err                    int,
		@local_c_errmsg                 NVARCHAR(254),
		@c_temp                         NVARCHAR(254)
	
   DECLARE @cPrevWaveKey    NVARCHAR(10),
           @cWaveKey        NVARCHAR(10),
           @cWaveDetailKey  NVARCHAR(10) 

	SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',
		@b_debug = 0, @local_n_err = 0, @local_c_errmsg = ' '
	
	IF ((@n_continue = 1 or @n_continue = 2) AND @copyrowstoarchivedatabase = 'y')
	BEGIN  
		IF (@b_debug =1 )
		BEGIN
			PRINT 'starting table existence check for Wave...'
		END
		SELECT @b_success = 1
		EXEC nsp_build_archive_table 
			@c_copyfrom_db, 
			@c_copyto_db, 
			'Wave',
			@b_success output , 
			@n_err output, 
			@c_errmsg output
		IF NOT @b_success = 1
		BEGIN
			SELECT @n_continue = 3
		END
	END

	IF ((@n_continue = 1 or @n_continue = 2) AND @copyrowstoarchivedatabase = 'y')
	BEGIN  
		IF (@b_debug =1 )
		BEGIN
			PRINT 'starting table existence check for WaveDetail...'
		END
		SELECT @b_success = 1
		EXEC nsp_build_archive_table 
			@c_copyfrom_db, 
			@c_copyto_db, 
			'WaveDetail',
			@b_success output , 
			@n_err output, 
			@c_errmsg output
		IF NOT @b_success = 1
		BEGIN
			SELECT @n_continue = 3
		END
	END

	IF ((@n_continue = 1 or @n_continue = 2) AND @copyrowstoarchivedatabase = 'y')
	BEGIN
		IF (@b_debug =1 )
		BEGIN
			PRINT 'building alter table string for WaveDetail...'
		END
		EXECUTE dbo.nspBuildAlterTableString 
			@c_copyto_db,
			'WaveDetail', -- SOS121711
			@b_success output,
			@n_err output, 
			@c_errmsg output
		IF NOT @b_success = 1
		BEGIN
			SELECT @n_continue = 3
		END
	END

	IF ((@n_continue = 1 or @n_continue = 2) AND @copyrowstoarchivedatabase = 'y') 
	BEGIN
		IF (@b_debug =1 )
		BEGIN
			PRINT 'building alter table string for Wave...'
		END
		EXECUTE dbo.nspBuildAlterTableString 
			@c_copyto_db,
			'Wave', -- SOS121711
			@b_success output,
			@n_err output, 
			@c_errmsg output
		IF NOT @b_success = 1
		BEGIN
			SELECT @n_continue = 3
		END
	END
   DECLARE @nWaveLines  int

	BEGIN TRAN

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DECLARE c_arc_Wave CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT WaveDetail.Wavekey, Count(*) As WaveLines 
         FROM WaveDetail (nolock)
         LEFT OUTER JOIN ORDERS (nolock) on (WaveDetail.orderkey = ORDERS.orderkey) 
         WHERE (ORDERS.archivecop = '9' OR ORDERS.orderkey IS NULL ) 
         GROUP BY WaveDetail.Wavekey 
         ORDER BY WaveDetail.Wavekey 
   
      SELECT @cPrevWaveKey = '' 
      SELECT @n_archive_Wave_records = 0 
      SELECT @n_archive_Wave_detail_records = 0 
   
      OPEN c_arc_Wave 
      
      FETCH NEXT FROM c_arc_Wave INTO @cWaveKey, @nWaveLines 
      WHILE @@fetch_status <> -1 AND (@n_continue=1 OR @n_continue=2) 
      BEGIN 
         IF (SELECT Count(*) FROM WaveDetail (nolock) WHERE Wavekey = @cWaveKey) = @nWaveLines
         BEGIN
            UPDATE Wave with (rowlock) 
   		      set Wave.archivecop = '9' 
            WHERE WaveKey = @cWaveKey 
            SELECT @local_n_err = @@error, @n_cnt = @@rowcount
      		SELECT @n_archive_Wave_records = @n_archive_Wave_records + 1
      		IF @local_n_err <> 0
      		BEGIN 
      			SELECT @n_continue = 3
      			SELECT @local_n_err = 77303
      			SELECT @local_c_errmsg = convert(char(5),@local_n_err)
      			SELECT @local_c_errmsg =
      			': update of archivecop failed - WaveDetail. (isp_ArchiveWave) ' + ' ( ' +
      			' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'
      		END  
   
            IF @n_continue=1 or @n_continue=2 
            BEGIN
               UPDATE WaveDetail
         		   SET WaveDetail.archivecop = '9'
               where WaveKey = @cWaveKey 
               SELECT @local_n_err = @@error, @n_cnt = @@rowcount
         		SELECT @n_archive_Wave_detail_records = @n_archive_Wave_detail_records + 1
         		IF @local_n_err <> 0
         		BEGIN 
         			SELECT @n_continue = 3
         			SELECT @local_n_err = 77303
         			SELECT @local_c_errmsg = convert(char(5),@local_n_err)
         			SELECT @local_c_errmsg =
         			': update of archivecop failed - WaveDetail. (isp_ArchiveWave) ' + ' ( ' +
         			' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'
         		END  
            END 
         END
   
         FETCH NEXT FROM c_arc_Wave INTO @cWaveKey, @nWaveLines 
      END
      CLOSE c_arc_Wave
      DEALLOCATE c_arc_Wave
   END -- @n_continue = 1 or @n_continue = 2


	IF ((@n_continue = 1 or @n_continue = 2)  AND @copyrowstoarchivedatabase = 'y')
	BEGIN
		SELECT @c_temp = 'attempting to archive ' + dbo.fnc_RTrim(convert(char(6),@n_archive_Wave_records )) +
			' Wave records AND ' + dbo.fnc_RTrim(convert(char(6),@n_archive_Wave_detail_records )) + ' WaveDetail records'
		EXECUTE dbo.nspLogAlert
			@c_modulename   = 'isp_ArchiveWave',
			@c_alertmessage = @c_temp ,
			@n_severity     = 0,
			@b_success       = @b_success output,
			@n_err          = @n_err output,
			@c_errmsg       = @c_errmsg output
		IF NOT @b_success = 1
		BEGIN
			SELECT @n_continue = 3
		END
	END

	IF ((@n_continue = 1 or @n_continue = 2) AND @copyrowstoarchivedatabase = 'y')
	BEGIN   
		IF (@b_debug =1 )
		BEGIN
			PRINT 'building insert for WaveDetail...'
		END
		SELECT @b_success = 1
		EXEC nsp_build_insert  
			@c_copyto_db, 
			'WaveDetail', -- SOS121711
			1,
			@b_success output , 
			@n_err output, 
			@c_errmsg output
		IF NOT @b_success = 1
		BEGIN
			SELECT @n_continue = 3
		END
	END

	IF ((@n_continue = 1 or @n_continue = 2) AND @copyrowstoarchivedatabase = 'y')
	BEGIN   
		IF (@b_debug =1 )
		BEGIN
			PRINT 'building insert for Wave...'
		END
		SELECT @b_success = 1
		EXEC nsp_build_insert  
			@c_copyto_db, 
			'Wave', -- SOS121711
			1,
			@b_success output , 
			@n_err output, 
			@c_errmsg output
		IF NOT @b_success = 1
		BEGIN
			SELECT @n_continue = 3
		END
	END

	IF @n_continue = 1 or @n_continue = 2
	BEGIN
		SELECT @b_success = 1
		EXECUTE dbo.nspLogAlert
			@c_modulename   = 'isp_ArchiveWave',
			@c_alertmessage = 'archive of Wave ENDed successfully.',
			@n_severity     = 0,
			@b_success       = @b_success output,
			@n_err          = @n_err output,
			@c_errmsg       = @c_errmsg output
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
			EXECUTE dbo.nspLogAlert
				@c_modulename   = 'isp_ArchiveWave',
				@c_alertmessage = 'archive of Wave failed - check this log for additional messages.',
				@n_severity     = 0,
				@b_success       = @b_success output ,
				@n_err          = @n_err output,
				@c_errmsg       = @c_errmsg output
			IF NOT @b_success = 1
			BEGIN
				SELECT @n_continue = 3
			END
		END
	END
     
	/* #include <sparpo2.sql> */     
	IF @n_continue=3  -- error occured - process AND return
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
		EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'isp_ArchiveWave'
		RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
		return
	END
	ELSE
	BEGIN
		SELECT @b_success = 1
		WHILE @@TRANCOUNT > @n_starttcnt
		BEGIN
			COMMIT TRAN
		END
		return
	END
END -- main

GO