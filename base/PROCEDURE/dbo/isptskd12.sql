SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Stored Procedure: ispTSKD12                                             */
/* Creation Date: 22-Mar-2024                                              */
/* Copyright: MAERSK                                                       */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: UWP-16615 - VNA Cancel Task Update TASKDETAIL Column           */
/*                                                                         */
/* Called By: isp_TaskDetail_Wrapper from Taskdetail Trigger               */
/*                                                                         */
/* Called By:                                                              */
/*                                                                         */
/* Version: 7.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 22-Mar-2024  WLChooi 1.0   DevOps Combine Script                        */
/***************************************************************************/
CREATE   PROC [dbo].[ispTSKD12]   
      @c_Action        NVARCHAR(10),
      @c_Storerkey     NVARCHAR(15),  
      @b_Success       INT      OUTPUT,
      @n_Err           INT      OUTPUT, 
      @c_ErrMsg        NVARCHAR(250) OUTPUT
AS   
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   DECLARE @n_Continue           INT
         , @n_StartTCnt          INT
         , @c_Taskdetailkey      NVARCHAR(10)
         , @c_Tasktype           NVARCHAR(10)
         , @c_ToLoc              NVARCHAR(10)
         , @c_ToLoc_Del          NVARCHAR(10)
         , @c_Userkey            NVARCHAR(18)
         , @c_Userkey_Del        NVARCHAR(18)
         , @c_Status             NVARCHAR(10)
         , @c_Status_Del         NVARCHAR(10)
         , @c_DeviceProfileKey   NVARCHAR(10)
         , @n_Fail2Queue         INT = 0
         , @n_Fail2Open          INT = 0
         , @c_Transmitlogkey     NVARCHAR(10)
         , @c_TableName          NVARCHAR(10)
         , @c_SuggestedLoc       NVARCHAR(10)
         , @c_ToID               NVARCHAR(18)
         , @c_ReservedID         NVARCHAR(18)
         , @c_Lot                NVARCHAR(10)
   SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1
   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      
   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END
   IF @c_Action = 'UPDATE' 
   BEGIN
      --Any status <> X OR 9 --> X OR 9
      DECLARE Cur_Task CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT I.Taskdetailkey, I.Tasktype, I.Lot, I.ToLoc, D.ToLoc, I.Userkey, D.Userkey
              , I.[Status], D.[Status]
         FROM #INSERTED I 
         JOIN #DELETED D ON I.Taskdetailkey = D.Taskdetailkey
         WHERE I.Storerkey = @c_Storerkey
         AND I.Tasktype IN ('VNAOUT', 'VNAIN')
         AND D.[Status] NOT IN ('X','9') 
         AND I.[Status] <> D.[Status]
         AND I.[Status] IN ('X','9','Q','0') 
      OPEN Cur_Task
      FETCH NEXT FROM Cur_Task INTO @c_Taskdetailkey, @c_Tasktype, @c_Lot, @c_ToLoc, @c_ToLoc_Del, @c_Userkey, @c_Userkey_Del
                                  , @c_Status, @c_Status_Del
      WHILE @@FETCH_STATUS <> -1 AND (@n_continue = 1 or @n_continue = 2)
      BEGIN
         SET @n_Fail2Queue = 0
         SET @n_Fail2Open = 0
         --Normal update process from backend job
         -- Q --> 0
         IF @c_Status_Del = 'Q' AND @c_Status = '0'
            GOTO NEXT
         IF @c_Status_Del IN ('0', 'F') AND @c_Status = 'Q'
            SET @n_Fail2Queue = 1
         ELSE IF @c_Status_Del = 'F' AND @c_Status = '0'
            SET @n_Fail2Open = 1
         --Retrigger ITF
         IF @n_Fail2Open = 1
         BEGIN
            SET @c_Transmitlogkey = N''
            SET @c_TableName = IIF(@c_Tasktype = 'VNAOUT', 'WSTSKPICKVNA', 'WSTSKMOVEVNA')
            SELECT @c_Transmitlogkey = Transmitlogkey
            FROM TransmitLog2 (NOLOCK) 
            WHERE TableName = @c_TableName 
            AND Key1 = @c_Taskdetailkey AND Key2 = @c_Userkey AND Key3 = @c_Storerkey
            IF ISNULL(@c_Transmitlogkey, '') <> ''
            BEGIN
               UPDATE dbo.TRANSMITLOG2
               SET Transmitflag = N'0'
               WHERE Transmitlogkey = @c_Transmitlogkey
               IF @@ERROR <> 0
               BEGIN
                  SELECT @n_Continue = 3 
                  SELECT @n_Err = 66000
                  SELECT @c_Errmsg = 'NSQL' + CONVERT(varchar(5),@n_Err)+': Failed to update Transmitlog2. (ispTSKD12)'
               END
            END
            ELSE
            BEGIN
               EXEC dbo.ispGenTransmitLog2 @c_TableName = @c_TableName
                                         , @c_Key1 = @c_Taskdetailkey
                                         , @c_Key2 = @c_Userkey
                                         , @c_Key3 = @c_Storerkey
                                         , @c_TransmitBatch = N''
                                         , @b_Success = @b_Success OUTPUT
                                         , @n_err = @n_err OUTPUT
                                         , @c_errmsg = @c_errmsg OUTPUT
               IF @@ERROR <> 0
               BEGIN
                  SELECT @n_Continue = 3 
                  SELECT @n_Err = 66005
                  SELECT @c_Errmsg = 'NSQL' + CONVERT(varchar(5),@n_Err)+': Failed to EXEC ispGenTransmitLog2. (ispTSKD12)'
               END
            END
         END
         ELSE   --Not updating Status F to 0
         BEGIN
            --Scenario:
            --Status -> X
            --Status -> 9
            --F --> Q
            --Cancel Task need update VNA Device to IDLE for VNAOUT and VNAIN
            IF @c_Status = 'X'
            BEGIN
               SET @c_DeviceProfileKey = N''
               SELECT TOP 1 @c_DeviceProfileKey = DP.DeviceProfileKey
               FROM DeviceProfile DP WITH (NOLOCK)
               WHERE DP.DeviceID = @c_Userkey_Del
               IF ISNULL(@c_DeviceProfileKey, '') <> ''
               BEGIN
                  UPDATE dbo.DeviceProfile
                  SET [Status] = 'IDLE'
                  WHERE DeviceProfileKey = @c_DeviceProfileKey
                  AND [Status] = 'BUSY'
                  IF @@ERROR <> 0
                  BEGIN
                     SELECT @n_Continue = 3 
                     SELECT @n_Err = 66010
                     SELECT @c_Errmsg = 'NSQL' + CONVERT(varchar(5),@n_Err)+': Failed to UPDATE DeviceProfile. (ispTSKD12)'
                  END
               END
            END
            IF @c_Tasktype = 'VNAOUT'
            BEGIN
               --Unlock PND PendingMoveIn
               SET @n_Err = 0
               SET @c_ReservedID = N''
               SELECT @c_ReservedID = ID
               FROM dbo.RFPutaway (NOLOCK)
               WHERE Taskdetailkey = @c_TaskdetailKey
               IF ISNULL(@c_ReservedID, '') = ''
                  SET @c_ReservedID = @c_ToID
               IF EXISTS( SELECT 1 FROM LOTXLOCXID (NOLOCK)
                          WHERE Lot = @c_Lot
                          AND Loc = @c_ToLoc
                          AND ID = @c_ReservedID )
               BEGIN
                  EXEC rdt.rdt_Putaway_PendingMoveIn 
                      @cUserName = ''
                     ,@cType = 'UNLOCK'
                     ,@cFromLoc = ''
                     ,@cFromID = ''
                     ,@cSuggestedLOC = ''
                     ,@cStorerKey = @c_Storerkey
                     ,@nErrNo = @n_Err OUTPUT
                     ,@cErrMsg = @c_Errmsg OUTPUT
                     ,@cSKU = ''
                     ,@nPutawayQTY    = 0
                     ,@cFromLOT       = ''
                     ,@cTaskDetailKey = @c_TaskdetailKey
                     ,@nFunc = 0
                     ,@nPABookingKey = 0
                  IF @n_Err <> 0
                  BEGIN
                     SELECT @n_Continue = 3 
                     SELECT @n_Err = 66015
                     SELECT @c_Errmsg = 'NSQL' + CONVERT(varchar(5),@n_Err)+': ' + @c_Errmsg + '. (ispTSKD12)'
                  END
               END
               --F --> Q
               --Clear userkey, backend job will update Userkey again
               IF @n_Fail2Queue = 1
               BEGIN
                  UPDATE TASKDETAIL
                  SET UserKey = ''
                    , TrafficCop = NULL
                    , EditDate = GETDATE()
                    , EditWho = SUSER_SNAME()
                  WHERE TaskDetailKey = @c_Taskdetailkey
                  IF @@ERROR <> 0
                  BEGIN
                     SELECT @n_Continue = 3 
                     SELECT @n_Err = 66020
                     SELECT @c_Errmsg = 'NSQL' + CONVERT(varchar(5),@n_Err)+': Update Taskdetail Failed. (ispTSKD12)'
                  END
               END
            END
         END
         NEXT:
         FETCH NEXT FROM Cur_Task INTO @c_Taskdetailkey, @c_Tasktype, @c_Lot, @c_ToLoc, @c_ToLoc_Del, @c_Userkey, @c_Userkey_Del
                                     , @c_Status, @c_Status_Del
      END
      CLOSE Cur_Task
      DEALLOCATE Cur_Task
   END
   ELSE IF @c_Action = 'DELETE' 
   BEGIN
      DECLARE Cur_Task_DEL CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT D.Taskdetailkey, D.Lot, D.ToLoc, D.ToID
         FROM #DELETED D 
         WHERE D.Storerkey = @c_Storerkey
         AND D.Tasktype IN ('VNAOUT')
         AND D.[Status] IN ('Q','0','1','2','3')
         ORDER BY D.Taskdetailkey
      OPEN Cur_Task_DEL
      FETCH NEXT FROM Cur_Task_DEL INTO @c_Taskdetailkey, @c_Lot, @c_ToLoc, @c_ToID
      WHILE @@FETCH_STATUS <> -1 AND (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         SET @n_Err = 0 
         SET @c_ReservedID = N''
         SELECT @c_ReservedID = ID
         FROM dbo.RFPutaway (NOLOCK)
         WHERE Taskdetailkey = @c_TaskdetailKey
         IF ISNULL(@c_ReservedID, '') = ''
            SET @c_ReservedID = @c_ToID
         IF EXISTS( SELECT 1 FROM LOTXLOCXID (NOLOCK)
                    WHERE Lot = @c_Lot
                    AND Loc = @c_ToLoc
                    AND ID = @c_ReservedID )
         BEGIN
            EXEC rdt.rdt_Putaway_PendingMoveIn   
                   @cUserName = ''
                  ,@cType = 'UNLOCK'
                  ,@cFromLoc = ''
                  ,@cFromID = ''
                  ,@cSuggestedLOC = ''
                  ,@cStorerKey = @c_Storerkey
                  ,@nErrNo = @n_Err OUTPUT
                  ,@cErrMsg = @c_Errmsg OUTPUT
                  ,@cSKU = ''
                  ,@nPutawayQTY    = 0
                  ,@cFromLOT       = ''
                  ,@cTaskDetailKey = @c_TaskdetailKey
                  ,@nFunc = 0
                  ,@nPABookingKey = 0
            IF @n_Err <> 0
            BEGIN
               SELECT @n_Continue = 3 
               SELECT @n_Err = 66025
               SELECT @c_Errmsg = 'NSQL' + CONVERT(varchar(5),@n_Err)+': ' + @c_Errmsg + '. (ispTSKD12)'
            END
         END
         FETCH NEXT FROM Cur_Task_DEL INTO @c_Taskdetailkey, @c_Lot, @c_ToLoc, @c_ToID
      END
      CLOSE Cur_Task_DEL
      DEALLOCATE Cur_Task_DEL
   END
   QUIT_SP:
   IF @n_Continue = 3  -- Error Occured - Process AND Return
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispTSKD12'      
      --RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END  
END  

GO