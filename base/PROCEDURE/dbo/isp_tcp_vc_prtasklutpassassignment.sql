SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
 /* Store Procedure:  isp_TCP_VC_prTaskLUTPassAssignment                 */
 /* Creation Date: 26-Feb-2013                                           */
 /* Copyright: IDS                                                       */
 /* Written by: Shong                                                    */
 /*                                                                      */
 /* Purposes: This message informs the host system to make the assignment*/
 /*            available for another operator.                           */
 /*                                                                      */
 /* Updates:                                                             */
 /* Date         Author    Purposes                                      */
 /************************************************************************/
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTPassAssignment] (
 @c_TranDate      NVARCHAR(20)
,@c_DevSerialNo   NVARCHAR(20)
,@c_OperatorID    NVARCHAR(20)
,@c_TaskDetailKey NVARCHAR(20)
,@n_SerialNo      INT
,@c_RtnMessage    NVARCHAR(500) OUTPUT
,@b_Success       INT = 1       OUTPUT
,@n_Error         INT = 0       OUTPUT
,@c_ErrMsg        NVARCHAR(255) = '' OUTPUT
)
AS
BEGIN
   DECLARE @c_ErrorCode   NVARCHAR(20) --  0: No error. The VoiceApplication proceeds.
                                    -- 98: Critical error. If this error is received,
                                    --     the VoiceApplication speaks the error message, and forces the operator to sign off.
                                    -- 99: Informational error. The VoiceApplication speaks the informational error message,
                                    --     but does not force the operator to sign off.
          ,@c_Message     NVARCHAR(400)
          ,@c_RegionNo    NVARCHAR(5) -- OperatorΓÇÿs response to picking region prompt.
          ,@c_RegionName  NVARCHAR(100)
          ,@c_TaskType    NVARCHAR(10)
          ,@c_LOT         NVARCHAR(10)
          ,@c_FromLoc     NVARCHAR(10)
          ,@c_FromID      NVARCHAR(18)
          ,@c_ToLOC       NVARCHAR(10)
          ,@c_ToID        NVARCHAR(18)
           
   
   
   SET @c_RtnMessage = ''
   SET @c_TaskType = ''
   SET @c_LOT = ''
   SET @c_FromLoc = ''
   SET @c_FromID = ''
   SET @c_ToLOC = ''
   SET @c_ToID = ''
   
   
   SELECT @c_TaskType = td.TaskType, 
          @c_LOT = td.Lot,
          @c_FromLoc = td.FromLoc,
          @c_FromID = td.FromID, 
          @c_ToLOC = td.ToLoc,
          @c_ToID  = td.ToID
   FROM TaskDetail td (NOLOCK)
   WHERE td.TaskDetailKey = @c_TaskDetailKey 
   
   SELECT @b_success = 0 
   EXECUTE nspAddSkipTasks 
   '' 
   , @c_OperatorID 
   , @c_TaskDetailkey 
   , @c_TaskType 
   , '' -- @c_caseid 
   , @c_LOT 
   , @c_FromLoc 
   , @c_FromID 
   , @c_ToLOC 
   , @c_ToID 
   , @b_Success OUTPUT 
   , @n_Error   OUTPUT 
   , @c_errmsg  OUTPUT        
   
   
   IF LEN(ISNULL(@c_RtnMessage ,'')) = 0
   BEGIN
       SET @c_RtnMessage = "0,"
   END
   

   
END

GO