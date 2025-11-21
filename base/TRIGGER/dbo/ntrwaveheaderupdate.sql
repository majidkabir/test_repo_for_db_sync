SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrWaveHeaderUpdate                                         */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  WAVE Update Transaction                                    */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Return Status:                                                       */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: When update records                                       */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Ver  Purposes                                */
/* 25 May 2012  TLTING01   1.0  DM integrity - add update editdate B4   */
/*                              TrafficCop                              */ 
/* 28-Oct-2013  TLTING     1.1  Review Editdate column update           */
/* 20-OCT-2022  NJOW01     1.2  WMS-21042 call custom stored proc       */
/* 20-OCT-2022  NJOW01     1.2  DEVOPS Combine Script                   */
/* 10-JAN-2025  YT01       1.3  Add Generic Interface Trigger           */
/************************************************************************/

CREATE   TRIGGER [dbo].[ntrWaveHeaderUpdate]
ON  [dbo].[WAVE] FOR UPDATE
AS
BEGIN
	IF @@ROWCOUNT = 0
	BEGIN
		RETURN
	END
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

	DECLARE @b_Success    int       -- Populated by calls to stored procedures - was the proc successful?
			, @n_err        int       -- Error number returned by stored procedure or this trigger
			, @n_err2       int       -- For Additional Error Detection
			, @c_errmsg     NVARCHAR(250) -- Error message returned by stored procedure or this trigger
			, @n_continue   int                 
			, @n_starttcnt  int       -- Holds the current transaction count
			, @c_preprocess NVARCHAR(250) -- preprocess
			, @c_pstprocess NVARCHAR(250) -- post process
			, @n_cnt        int                  

	SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
	
	IF UPDATE(ArchiveCop)
	BEGIN
		SELECT @n_continue = 4 
	END	
   --tlting01
	IF ( @n_continue = 1 or @n_continue=2 ) AND NOT UPDATE(EditDate)
	BEGIN
		UPDATE WAVE
		SET EditDate = GETDATE(),
		    EditWho  = SUSER_SNAME(),
		    TrafficCop = NULL
		FROM WAVE (NOLOCK), INSERTED (NOLOCK)
      WHERE WAVE.WaveKey = INSERTED.WaveKey
		SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

		IF @n_err <> 0
		BEGIN
			SELECT @n_continue = 3
			SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=69701   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
			SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table WAVE. (ntrWaveHeaderUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
		END
	END

	IF UPDATE(TrafficCop)
	BEGIN
		SELECT @n_continue = 4 
	END

   --(YT01)-S
   DECLARE @b_ColumnsUpdated VARBINARY(1000)  
          ,@c_WaveKey        NVARCHAR(10)
          ,@c_Storerkey      NVARCHAR(15)

   SET @b_ColumnsUpdated = COLUMNS_UPDATED()  
   --(YT01)-E
	
  --NJOW01
  IF @n_continue=1 or @n_continue=2                 
  BEGIN          
     IF EXISTS (SELECT 1 FROM DELETED d     
                JOIN WAVEDETAIL wd WITH (NOLOCK) ON d.Wavekey = wd.Wavekey     
                JOIN ORDERS       o WITH (NOLOCK) ON wd.OrderKey = o.OrderKey 
                JOIN storerconfig s WITH (NOLOCK) ON o.storerkey = s.storerkey          
                JOIN sys.objects sys WITH (NOLOCK) ON sys.type = 'P' AND sys.name = s.Svalue          
                WHERE  s.configkey = 'WaveTrigger_SP')          
     BEGIN          
        IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL          
           DROP TABLE #INSERTED          
            
        SELECT *          
        INTO #INSERTED          
        FROM INSERTED          
            
        IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL          
           DROP TABLE #DELETED          
            
        SELECT *          
        INTO #DELETED          
        FROM DELETED          
            
        EXECUTE dbo.isp_WaveTrigger_Wrapper          
                  'UPDATE'  --@c_Action          
                , @b_Success  OUTPUT          
                , @n_Err      OUTPUT          
                , @c_ErrMsg   OUTPUT          
            
        IF @b_success <> 1          
        BEGIN          
           SELECT @n_continue = 3          
                 ,@c_errmsg = 'ntrWaveHeaderUpdate ' + RTRIM(LTRIM(ISNULL(@c_errmsg,'')))          
        END          
            
        IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL          
           DROP TABLE #INSERTED          
            
        IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL          
           DROP TABLE #DELETED          
     END          
  END          	

   --(YT01)-S
   /********************************************************/
   /* Interface Trigger Points Calling Process - (Start)   */
   /********************************************************/
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE Cur_TriggerPoints CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT INS.WaveKey, OH.StorerKey
      FROM   INSERTED INS
      JOIN   WAVEDETAIL WD WITH (NOLOCK)        ON INS.WaveKey = WD.WaveKey
      JOIN   Orders OH WITH (NOLOCK)            ON WD.OrderKey = OH.OrderKey
      JOIN   ITFTriggerConfig ITC WITH (NOLOCK) ON ITC.StorerKey = OH.StorerKey
      WHERE  ITC.SourceTable = 'WAVE'
      AND    ITC.sValue      = '1'

      OPEN Cur_TriggerPoints
      FETCH NEXT FROM Cur_TriggerPoints INTO @c_WaveKey, @c_Storerkey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         EXECUTE dbo.isp_ITF_ntrWave
                  @c_TriggerName    = 'ntrWaveHeaderUpdate'
                , @c_SourceTable    = 'WAVE'
                , @c_Storerkey      = @c_Storerkey
                , @c_WaveKey        = @c_WaveKey
                , @b_ColumnsUpdated = @b_ColumnsUpdated
                , @b_Success        = @b_Success   OUTPUT
                , @n_err            = @n_err       OUTPUT
                , @c_errmsg         = @c_errmsg    OUTPUT

         FETCH NEXT FROM Cur_TriggerPoints INTO @c_WaveKey, @c_Storerkey
      END -- WHILE @@FETCH_STATUS <> -1
      CLOSE Cur_TriggerPoints
      DEALLOCATE Cur_TriggerPoints

      DECLARE Cur_TriggerPoints CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT INS.WaveKey, OH.StorerKey
      FROM   INSERTED INS
      JOIN   WAVEDETAIL WD WITH (NOLOCK)        ON INS.WaveKey   = WD.WaveKey
      JOIN   Orders OH WITH (NOLOCK)            ON WD.OrderKey   = OH.OrderKey
      JOIN   ITFTriggerConfig ITC WITH (NOLOCK) ON ITC.StorerKey = 'ALL'
      JOIN   StorerConfig STC WITH (NOLOCK)     ON OH.StorerKey = STC.StorerKey AND STC.ConfigKey = ITC.ConfigKey AND STC.SValue = '1'
      WHERE  ITC.SourceTable = 'WAVE'
      AND    ITC.sValue      = '1'

      OPEN Cur_TriggerPoints
      FETCH NEXT FROM Cur_TriggerPoints INTO @c_WaveKey, @c_Storerkey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         EXECUTE dbo.isp_ITF_ntrWave
                  @c_TriggerName    = 'ntrWaveHeaderUpdate'
                , @c_SourceTable    = 'WAVE'
                , @c_Storerkey      = @c_Storerkey
                , @c_WaveKey        = @c_WaveKey
                , @b_ColumnsUpdated = @b_ColumnsUpdated
                , @b_Success        = @b_Success   OUTPUT
                , @n_err            = @n_err       OUTPUT
                , @c_errmsg         = @c_errmsg    OUTPUT

         FETCH NEXT FROM Cur_TriggerPoints INTO @c_WaveKey, @c_Storerkey
      END -- WHILE @@FETCH_STATUS <> -1
      CLOSE Cur_TriggerPoints
      DEALLOCATE Cur_TriggerPoints
   END -- IF @n_continue = 1 OR @n_continue = 2
   /********************************************************/
   /* Interface Trigger Points Calling Process - (End)     */
   /********************************************************/
	--(YT01)-E

	   /* #INCLUDE <TRTHU1.SQL> */     


      /* #INCLUDE <TRTHU2.SQL> */
	IF @n_continue=3  -- Error Occured - Process And Return
	BEGIN
		IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt
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
		execute nsp_logerror @n_err, @c_errmsg, 'ntrWaveHeaderUpdate'
		RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
		RETURN
	 END
	 ELSE
	 BEGIN
		 WHILE @@TRANCOUNT > @n_starttcnt
		 BEGIN
			 COMMIT TRAN
		 END
		 RETURN
	 END
END

GO