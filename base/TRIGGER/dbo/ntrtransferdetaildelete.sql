SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ntrTransferDetailDelete                               */
/* Creation Date:                                                          */
/* Copyright: IDS                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose:                                                                */                               
/*        :                                                                */
/* Called By:                                                              */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.5                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 17-Mar-2009  TLTING        Change user_name() to SUSER_SNAME()          */
/* 12-May-2011  KHLim01       Insert Delete log                            */
/* 14-Jul-2011  KHLim02 1.2   GetRight for Delete log                      */
/* 23-APR-2014  YTWan   1.3   SOS#304838 - ANF - Allocation strategy       */
/*                            for Transfer (Wan01)                         */  
/* 24-NOV-2014  YTWan   1.4   SOS#315609 - Project Merlion - Transfer      */
/*                            Release Task.(Wan02)                         */  
/* 13-OCT-2015  YTWan   1.4   SOS#345583 - cn_update tranfer header (Wan03)*/
/* 23-FEB-2021  Wan04   1.5   WMS-16391 - [CN] ANFQHW_WMS_Transfer Finalize_CR */
/***************************************************************************/
CREATE TRIGGER ntrTransferDetailDelete
ON TRANSFERDETAIL
FOR DELETE
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

   DECLARE @b_debug int
   SELECT @b_debug =0
   IF @b_debug = 1
   BEGIN
      SELECT "DELETED ", * FROM DELETED
   END
   ELSE IF @b_debug = 2
   BEGIN
      DECLARE @profiler NVARCHAR(80)
      SELECT @profiler = "PROFILER,701,00,0,ntrTransferDetailDelete Trigger                    ," + CONVERT(char(12), getdate(), 114)
      PRINT @profiler
   END
   DECLARE @b_Success       int,       -- Populated by calls to stored procedures - was the proc successful?
           @n_err              int,       -- Error number returned by stored procedure or this trigger
           @c_errmsg           NVARCHAR(250), -- Error message returned by stored procedure or this trigger
           @n_continue         int,       -- continuation flag: 1 = Continue, 2 = failed but continue processsing, 3 = failed do not continue processing, 4 = successful but skip further processing
           @n_starttcnt        int,       -- Holds the current transaction count
           @n_cnt              int        -- Holds the number of rows affected by the DELETE statement that fired this trigger.
         , @c_authority        NVARCHAR(1)  -- KHLim02

         , @c_Facility              NVARCHAR(5)   -- (Wan02)
         , @c_FromStorerkey         NVARCHAR(15)  -- (Wan02)
         , @c_AllowDelete           NVARCHAR(15)  -- (Wan02)
         , @c_AllowDelRelTrfID      NVARCHAR(10)  -- (Wan02)
         , @c_SPCode                NVARCHAR(10)  -- (Wan02)
         , @c_Transferkey           NVARCHAR(10)  -- (Wan02)
         , @c_TransferLineNumber    NVARCHAR(5)   -- (Wan02)
         , @c_FromLoc               NVARCHAR(10)  -- (Wan02)
         , @c_FromID                NVARCHAR(18)  -- (Wan02)
         , @c_Status                NVARCHAR(10)  -- (Wan02)
         , @c_SQL                   NVARCHAR(MAX) -- (Wan02) 
         
         , @c_HoldChannel           NVARCHAR(10)   = ''  --(Wan04)
         , @c_HoldTRFType           CHAR(1)        = ''  --(Wan04)
         , @c_TRFAllocHoldChannel   NVARCHAR(30)   = ''  --(Wan04)
         , @n_FromChannel_ID        BIGINT         = 0   --(Wan04)
         , @n_FromQty               INT            = 0   --(Wan04)

   SELECT @n_continue = 1, @n_starttcnt = @@TRANCOUNT
      /* #INCLUDE <TRTDD1.SQL> */     
   IF (select count(*) from DELETED) =
    (select count(*) from DELETED where DELETED.ArchiveCop = '9')
   BEGIN
      SELECT @n_continue = 4
   END

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
         IF EXISTS ( SELECT *
                     FROM DELETED
                     WHERE Status = "9" )
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 70101
            SELECT @c_errmsg = "NSQL"+CONVERT(char(5),@n_err)+": Posted rows may not be deleted. (ntrTransferDetailDelete)"
         END
      END

      --(Wan02) - START
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
--         SELECT TOP 1 @c_facility = TRANSFER.Facility
--                     ,@c_fromstorerkey = DELETED.FromStorerkey
--         FROM DELETED 
--         JOIN TRANSFER WITH (NOLOCK) ON (DELETED.Transferkey = TRANSFER.Transferkey)
         DECLARE CUR_GETRIGHT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT DISTINCT
                TRANSFER.Facility
               ,DELETED.FromStorerkey
               ,DELETED.Transferkey
         FROM DELETED
         JOIN TRANSFER WITH (NOLOCK) ON (DELETED.Transferkey = TRANSFER.Transferkey)

         OPEN CUR_GETRIGHT

         FETCH NEXT FROM CUR_GETRIGHT INTO @c_facility
                                          ,@c_fromstorerkey
                                          ,@c_Transferkey

         WHILE @@FETCH_STATUS <> -1 AND @n_continue = 1
         BEGIN
            EXECUTE nspGetRight
                     @c_Facility       -- Facility
                  ,  @c_FromStorerKey  -- Storer
                  ,  NULL              -- Sku
                  ,  'AllowDelReleasedTransferID'  -- ConfigKey
                  ,  @b_success          OUTPUT 
                  ,  @c_AllowDelRelTrfID OUTPUT 
                  ,  @n_err              OUTPUT 
                  ,  @c_errmsg           OUTPUT

            IF @b_Success <> 1 
            BEGIN
               SET @n_continue = 3
               SET @c_errmsg = CONVERT(CHAR(250),@n_err)
               SET @n_err = 68105   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Retrieve Failed On GetRight - IDTaskReleased. (ntrTransferDetailDelete)' 
                            + ' ( ' + ' SQLSvr MESSAGE = ' + LTrim(RTrim(@c_errmsg)) + ' ) '
            END

            EXECUTE nspGetRight
                     @c_Facility       -- Facility
                  ,  @c_FromStorerKey  -- Storer
                  ,  NULL              -- Sku
                  ,  'PostFinalizeTranferSP'  -- ConfigKey
                  ,  @b_success        OUTPUT 
                  ,  @c_SPCode         OUTPUT 
                  ,  @n_err            OUTPUT 
                  ,  @c_errmsg         OUTPUT

            IF @b_Success <> 1 
            BEGIN
               SET @n_continue = 3
               SET @c_errmsg = CONVERT(CHAR(250),@n_err)
               SET @n_err = 68110   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Retrieve Failed On GetRight - ReleaseTransfer_SP. (ntrTransferDetailDelete)' 
                            + ' ( ' + ' SQLSvr MESSAGE = ' + LTrim(RTrim(@c_errmsg)) + ' ) '
            END

            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               IF EXISTS ( SELECT 1
                           FROM DELETED
                           WHERE DELETED.Transferkey = @c_Transferkey
                           AND DELETED.Status IN ('4', '5') 
                         )
               BEGIN
                  SET @c_AllowDelete = 'N'
                  IF @c_AllowDelRelTrfID = '1' 
                  BEGIN 
                     IF EXISTS (SELECT 1
                                FROM DELETED WITH (NOLOCK)
                                LEFT JOIN TASKDETAIL WITH (NOLOCK) ON (DELETED.TransferKey = TASKDETAIL.Sourcekey) 
                                                                   AND(DELETED.FromLoc = TASKDETAIL.FromLoc)
                                                                   AND(DELETED.FromID = TASKDETAIL.FromID)
                                WHERE  DELETED.Transferkey = @c_Transferkey
                                AND   ((DELETED.Status = '5') 
                                OR    (DELETED.Status = '4'
                                AND   TASKDETAIl.TaskType = 'ASRSTRF' 
                                AND   TASKDETAIL.Status = 'X'))
                                      )
                     BEGIN
                        SET @c_AllowDelete = 'Y'
                     END
                  END 
          
                  IF @c_AllowDelete = 'N'
                  BEGIN
                     SET @n_Continue = 3
                     SET @n_err = 68115
                     SET @c_errmsg = 'NSQL'+CONVERT(Char(5),@n_err)+': Delete Released Detail. '
                                   + 'DELETE rejected (ntrTRANSFERDETAILDelete)' 
                  END
               END
            END 
            
            --(Wan04) - START
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
               SELECT @c_TRFAllocHoldChannel = SC.Authority
               FROM fnc_SelectGetRight (@c_Facility, @c_FromStorerKey, '', 'TRFAllocHoldChannel') SC
            END
            --(Wan04) - END

            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
               DECLARE CUR_DELDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
               SELECT Transferkey
                     ,TransferLineNumber
                     ,FromLoc
                     ,FromID
                     ,STATUS
                     ,FromChannel_ID                                 --(Wan04)
                     ,FromQty                                        --(Wan04)    
               FROM DELETED
               WHERE DELETED.TransferKey = @c_Transferkey
               ORDER BY TransferLineNumber
               
               OPEN CUR_DELDET

               FETCH NEXT FROM CUR_DELDET INTO @c_Transferkey
                                             , @c_TransferLineNumber
                                             , @c_FromLoc
                                             , @c_FromID
                                             , @c_Status
                                             , @n_FromChannel_ID     --(Wan04)
                                             , @n_FromQty            --(Wan04)

               WHILE @@FETCH_STATUS <> -1 AND @n_continue = 1
               BEGIN
                  --(Wan04) - START
                  ---------------------------------------------------------------------------------
                  -- Release From Channel Hold that was hold at transfer allocation process (START)
                  ---------------------------------------------------------------------------------
                  IF @n_continue = 1 AND @c_TRFAllocHoldChannel = '1' AND @n_FromChannel_ID > 0 AND
                     EXISTS ( SELECT 1 
                              FROM ChannelInvHold AS cih WITH (NOLOCK)
                              JOIN ChannelInvHoldDetail AS cihd WITH (NOLOCK) ON  cihd.InvHoldkey = cih.InvHoldkey
                              WHERE cih.HoldType = 'TRF'
                              AND cih.Sourcekey = @c_TransferKey
                              AND cihd.SourceLineNo = @c_TransferLineNumber
                              AND CIHD.Channel_ID = @n_FromChannel_ID
                              AND cihd.Hold = '1'
                           )
                  BEGIN
                     SET @c_HoldTRFType = 'F'
                     SET @c_HoldChannel = '0'
                     EXEC isp_ChannelInvHoldWrapper  
                          @c_HoldType     = 'TRF'         
                        , @c_SourceKey    = @c_Transferkey    
                        , @c_SourceLineNo = @c_TransferLineNumber                                 
                        , @c_Facility     = ''       
                        , @c_Storerkey    = ''       
                        , @c_Sku          = ''       
                        , @c_Channel      = ''       
                        , @c_C_Attribute01= ''       
                        , @c_C_Attribute02= ''       
                        , @c_C_Attribute03= ''       
                        , @c_C_Attribute04= ''       
                        , @c_C_Attribute05= ''       
                        , @n_Channel_ID   = @n_FromChannel_ID       
                        , @c_Hold         = @c_HoldChannel     
                        , @c_Remarks      = ''  
                        , @c_HoldTRFType  = @c_HoldTRFType 
                        , @n_DelQty       = @n_FromQty
                        , @n_QtyHoldToAdj = 0   
                        , @n_ChannelTran_ID_Ref = 0      
                        , @b_Success      = @b_Success   OUTPUT  
                        , @n_Err          = @n_Err       OUTPUT  
                        , @c_ErrMsg       = @c_ErrMsg    OUTPUT  
  
                     IF @b_Success = 0  
                     BEGIN  
                        SET @n_continue = 3  
                        SET @n_err = 68116 
                        SET @c_errmsg  = CONVERT(char(5),@n_err)+': Error Executing isp_ChannelInvHoldWrapper. (ntrTransferDetailDelete)'  
                     END 
                  END               
                  ---------------------------------------------------------------------------------
                  -- Release From Channel Hold that was hold at transfer allocation process (END)
                  ---------------------------------------------------------------------------------
                  --(Wan04) - END

                  IF @c_Status IN ('4', '5') AND @c_AllowDelRelTrfID = '1' AND @n_continue = 1  --(Wan04)
                  BEGIN
                     IF NOT EXISTS ( SELECT 1
                                     FROM TRANSFERDETAIL WITH (NOLOCK)
                                     WHERE TransferKey = @c_Transferkey
                                     AND FromLoc = @c_FromLoc
                                     AND FromID  = @c_FromID
                                     AND Status IN ('4','5')
                                   ) AND
                        NOT EXISTS ( SELECT 1
                                     FROM DELETED
                                     WHERE TransferKey = @c_Transferkey
                                     AND TransferLineNumber > @c_TransferLineNumber
                                     AND FromLoc = @c_FromLoc
                                     AND FromID  = @c_FromID
                                     AND Status IN ('4','5')
                                   ) AND
                        @c_SPCode <> '0'
                     BEGIN

                        IF EXISTS (SELECT 1 FROM sys.objects o WHERE NAME = @c_SPCode AND TYPE = 'P')
                        BEGIN
                           SET @c_SQL = N'EXEC ' + @c_SPCode  
                                      + ' @c_TransferKey = @c_TransferKey'
                                      + ',@b_Success    = @b_Success  OUTPUT'
                                      + ',@n_Err        = @n_Err      OUTPUT'
                                      + ',@c_ErrMsg     = @c_ErrMsg   OUTPUT'
                                      + ',@c_ID         = @c_ID'
                                      + ',@c_UpdateToID = @c_UpdateToID'
                                
                           EXEC sp_executesql @c_SQL
                              ,  N'@c_TransferKey  NVARCHAR(10)
                                  ,@b_Success      INT OUTPUT
                                  ,@n_Err          INT OUTPUT
                                  ,@c_ErrMsg       NVARCHAR(255) OUTPUT  
                                  ,@c_ID           NVARCHAR(18) 
                                  ,@c_UpdateToID   NVARCHAR(1)' 

                              ,  @c_TransferKey
                              ,  @b_Success OUTPUT   
                              ,  @n_Err     OUTPUT
                              ,  @c_ErrMsg  OUTPUT
                              ,  @c_FromID
                              ,  'N'

                           IF @b_Success <> 1 
                           BEGIN
                              SET @n_Continue = 3
                              SET @c_errmsg = CONVERT(CHAR(250),@n_err)
                              SET @n_err = 68120
                              SET @c_errmsg = 'NSQL'+CONVERT(Char(5),@n_err)+': Release Hold ID ' + @c_FromID + ' failed. ' 
                                            + '(ntrTRANSFERDETAILDelete) ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
                           END
                        END
                     END
                  END

                  FETCH NEXT FROM CUR_DELDET INTO @c_Transferkey
                                                , @c_TransferLineNumber
                                                , @c_FromLoc
                                                , @c_FromID
                                                , @c_Status
                                                , @n_FromChannel_ID  --(Wan04)
                                                , @n_FromQty         --(Wan04)
               END
               CLOSE CUR_DELDET
               DEALLOCATE CUR_DELDET
            END 
            FETCH NEXT FROM CUR_GETRIGHT INTO @c_facility
                                             ,@c_fromstorerkey
                                             ,@c_Transferkey
         END
         CLOSE CUR_GETRIGHT
         DEALLOCATE CUR_GETRIGHT
      END
      --(Wan02) - END

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         IF @b_debug = 2
         BEGIN
            SELECT @profiler = "PROFILER,701,02,0,TRANSFER                                     ," + CONVERT(char(12), getdate(), 114)
            PRINT @profiler
         END
         DECLARE @n_deletedcount int
         SELECT @n_deletedcount = (select count(*) FROM deleted)
         IF @n_deletedcount = 1
         BEGIN
            UPDATE TRANSFER
            SET  TRANSFER.OpenQty = TRANSFER.OpenQty - DELETED.FromQty,
            EditDate = GETDATE(),  -- SOS102519
            EditWho = SUSER_SNAME(), -- SOS102519
            Trafficcop = Null        -- SOS102519
            FROM TRANSFER,
            DELETED
            WHERE TRANSFER.TransferKey = DELETED.TransferKey
            AND NOT EXISTS ( SELECT 1                                      --(Wan03)
                             FROM TRANSFERDETAIL TD WITH (NOLOCK)          --(Wan03)
                             WHERE TD.TransferKey = DELETED.Transferkey    --(Wan03)
                           )                                               --(Wan03)            
         END
         ELSE
         BEGIN
            UPDATE TRANSFER SET TRANSFER.OpenQty
            = (TRANSFER.Openqty
            -
            (Select Sum(DELETED.FromQty) From DELETED
            Where DELETED.Transferkey = TRANSFER.Transferkey)
            ),
            EditDate = GETDATE(),  -- SOS102519
            EditWho = SUSER_SNAME(), -- SOS102519
            Trafficcop = Null        -- SOS102519
            FROM TRANSFER,DELETED
            WHERE TRANSFER.Transferkey IN (SELECT Distinct Transferkey From DELETED)
            AND TRANSFER.Transferkey = DELETED.Transferkey
            AND NOT EXISTS ( SELECT 1                                      --(Wan03)        
                             FROM TRANSFERDETAIL TD WITH (NOLOCK)          --(Wan03)
                             WHERE TD.TransferKey = DELETED.Transferkey    --(Wan03)
                           )                                               --(Wan03)            
         END
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 70102   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = "NSQL"+CONVERT(char(5),@n_err)+": Insert failed on table TRANSFER. (ntrTransferDetailDelete)" + " ( " + " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
         IF @b_debug = 2
         BEGIN
            SELECT @profiler = "PROFILER,701,02,9,TRANSFER Update                                   ," + CONVERT(char(12), getdate(), 114)
            PRINT @profiler
         END

         --(Wan03) - START
         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            IF @n_deletedcount = 1
            BEGIN
               UPDATE TRANSFER
               SET  TRANSFER.OpenQty = TRANSFER.OpenQty - DELETED.FromQty 
                  , EditDate = GETDATE()  
                  , EditWho = SUSER_SNAME()  
               FROM TRANSFER 
               JOIN DELETED ON (TRANSFER.TransferKey = DELETED.TransferKey)
               AND EXISTS ( SELECT 1 
                            FROM TRANSFERDETAIL TD WITH (NOLOCK)
                            WHERE TD.TransferKey = DELETED.Transferkey
                          ) 
            END
            ELSE
            BEGIN
               UPDATE TRANSFER SET TRANSFER.OpenQty
               = (TRANSFER.Openqty
               -
               (SELECT SUM(DELETED.FromQty) FROM DELETED
                WHERE DELETED.Transferkey = TRANSFER.Transferkey)
               )
               , EditDate = GETDATE()  
               , EditWho = SUSER_SNAME() 
               FROM TRANSFER
               JOIN DELETED ON (TRANSFER.TransferKey = DELETED.TransferKey)
               WHERE TRANSFER.Transferkey IN (SELECT DISTINCT Transferkey FROM DELETED)
               AND EXISTS ( SELECT 1 
                            FROM TRANSFERDETAIL TD WITH (NOLOCK)
                            WHERE TD.TransferKey = DELETED.Transferkey
                           ) 
            END
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 70102   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Insert failed on table TRANSFER. (ntrTransferDetailDelete)' 
                                + ' ( ' + ' SQLSvr MESSAGE = ' + RTRIM(@c_errmsg) + ' ) '
            END
         END
         --(Wan03) - END         
      END
   END



   --(Wan01) - START
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF EXISTS ( SELECT 1
                  FROM DELETED
                  JOIN TRANSFER TF WITH (NOLOCK) ON (DELETED.TransferKey = TF.Transferkey)
                  WHERE TF.Status = '3'
                )
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 68100
         SET @c_errmsg = 'NSQL'+CONVERT(Char(5),@n_err)+': Delete Allocated Transfer Detail. DELETE rejected (ntrTRANSFERDETAILDelete)' 
      END
   END
   --(Wan01) - END

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
               ,@c_errmsg = 'ntrTransferDetailDelete' + dbo.fnc_RTrim(@c_errmsg)
      END
      ELSE 
      IF @c_authority = '1'         --    End   (KHLim02)
      BEGIN
         INSERT INTO dbo.TRANSFERDETAIL_DELLOG ( TransferKey, TransferLineNumber )
         SELECT TransferKey, TransferLineNumber FROM DELETED

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table TRANSFERDETAIL Failed. (ntrTRANSFERDETAILDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
         END
      END
   END
   -- End (KHLim01) 

      /* #INCLUDE <TRTDD2.SQL> */
 IF @n_continue = 3  -- Error Occured - Process And Return
 BEGIN
 IF @@TRANCOUNT = 1 and @@TRANCOUNT > = @n_starttcnt
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
 EXECUTE nsp_logerror @n_err, @c_errmsg, "ntrTransferDetailDelete"
 RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
 IF @b_debug = 2
 BEGIN
 SELECT @profiler = "PROFILER,701,00,9,ntrTransferDetailDelete Trigger                    ," + CONVERT(char(12), getdate(), 114)
 PRINT @profiler
 END
 RETURN
 END
 ELSE
 BEGIN
 WHILE @@TRANCOUNT > @n_starttcnt
 BEGIN
 COMMIT TRAN
 END
 IF @b_debug = 2
 BEGIN
 SELECT @profiler = "PROFILER,701,00,9,ntrTransferDetailDelete Trigger                    ," + CONVERT(char(12), getdate(), 114)
 PRINT @profiler
 END
 RETURN
 END
 END



GO