SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrWaveHeaderDelete                                         */
/* Creation Date: 10-Feb-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by:wtshong                                                   */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* GIT Version: 1.0                                                     */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Ver  Purposes                                */
/* 09-Jun-2011  KHLim01    1.1  Insert Delete log                       */
/* 14-Jul-2011  KHLim02    1.2  GetRight for Delete log                 */
/* 06-Oct-2016  TLTING     1.3  SET Option                              */
/* 20-OCT-2022  NJOW01     1.4  WMS-21042 call custom stored proc       */
/* 20-OCT-2022  NJOW01     1.4  DEVOPS Combine Script                   */
/************************************************************************/

CREATE   TRIGGER [dbo].[ntrWaveHeaderDelete]
ON [dbo].[WAVE] FOR DELETE
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

   DECLARE @b_Success          int,       -- Populated by calls to stored procedures - was the proc successful?
           @n_err              int,       -- Error number returned by stored procedure or this trigger
           @c_errmsg           NVARCHAR(250), -- Error message returned by stored procedure or this trigger
           @n_continue         int,       -- continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip further processing
           @n_starttcnt        int,       -- Holds the current transaction count
           @n_cnt              int,        -- Holds the number of rows affected by the DELETE statement that fired this trigger.
           @c_authority        NVARCHAR(1)  -- KHLim02
   
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
   if (select count(*) from DELETED) =
      (select count(*) from DELETED where DELETED.ArchiveCop = '9')
   BEGIN
      SELECT @n_continue = 4
   END
        /* #INCLUDE <TRWAVEHD1.SQL> */     
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF EXISTS (SELECT * FROM DELETED WHERE Status = "9")
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 84502
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": DELETE rejected. WAVE.Status = 'Shipped'. (ntrWaveHeaderDelete)"
      END
   END
   
    --NJOW01
   IF @n_continue=1 or @n_continue=2          
   BEGIN
      IF EXISTS (SELECT 1 FROM DELETED d  
                 JOIN WAVEDETAIL wd WITH (NOLOCK) ON d.Wavekey = wd.Wavekey     
                 JOIN ORDERS       o WITH (NOLOCK) ON wd.OrderKey = o.OrderKey 
                 JOIN storerconfig s WITH (NOLOCK) ON  o.storerkey = s.storerkey    
                 JOIN sys.objects sys ON sys.type = 'P' AND sys.name = s.Svalue
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
                   'DELETE'  --@c_Action
                 , @b_Success  OUTPUT  
                 , @n_Err      OUTPUT   
                 , @c_ErrMsg   OUTPUT  
   
         IF @b_success <> 1  
         BEGIN  
            SELECT @n_continue = 3  
                  ,@c_errmsg = 'ntrWaveHeaderDelete ' + RTRIM(LTRIM(ISNULL(@c_errmsg,'')))
         END  
         
         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
            DROP TABLE #INSERTED
   
         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
            DROP TABLE #DELETED
      END
   END   
   
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DELETE WaveDetail FROM WaveDetail, Deleted
      WHERE WaveDetail.WaveKey=Deleted.WaveKey
      
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 84501   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete Trigger On Table WaveDETAIL Failed. (ntrWaveHeaderDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END
 
    -- Start (KHLim01)
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @b_success = 0         --    Start (KHLim02)
      EXECUTE nspGetRight  NULL,             -- facility  
                           NULL,             -- Storerkey  
                           NULL,             -- Sku  
                           'DataMartDELLOG', -- Configkey  
                           @b_success     OUTPUT, 
                           @c_authority   OUTPUT, 
                           @n_err         OUTPUT, 
                           @c_errmsg      OUTPUT  
      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3
               ,@c_errmsg = 'ntrWaveHeaderDelete' + dbo.fnc_RTrim(@c_errmsg)
      END
      ELSE 
      IF @c_authority = '1'         --    End   (KHLim02)
      BEGIN
         INSERT INTO dbo.WAVE_DELLOG ( WaveKey )
         SELECT WaveKey  FROM DELETED

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table ORDERS Failed. (ntrWAVEDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
         END
      END
   END
   -- End (KHLim01)

      /* #INCLUDE <TRWAVEHD2.SQL> */
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
      
      EXECUTE nsp_logerror @n_err, @c_errmsg, "ntrWaveHeaderDelete"
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