SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: ispPARL04                                          */  
/* Creation Date: 26-JUL-2019                                           */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-11477 - TH Nike Putaway - Release PA Tasks              */  
/*                                                                      */ 
/* Input Parameters:  @c_ReceiptKey                                     */
/*                                                                      */
/* Output Parameters:  @b_Success                                       */
/*                   , @n_err                                           */
/*                   , @c_errmsg                                        */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */ 
/* Called By: isp_ASNReleasePATask_Wrapper                              */  
/*            Storerconfig: ASNReleasePATask_SP = 'ispPARL04'           */
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/  

CREATE PROC [dbo].[ispPARL04] 
   @c_ReceiptKey  NVARCHAR(10),
   @b_Success     INT OUTPUT, 
   @n_err         INT OUTPUT, 
   @c_errmsg      NVARCHAR(250) OUTPUT 
AS
BEGIN
   SET NOCOUNT ON       -- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE @n_continue        INT
         , @n_StartTCnt       INT
         , @n_NoOfTasks       INT
         , @c_TaskDetailKey   NVARCHAR(10)
         , @c_Storerkey       NVARCHAR(15)
         , @c_SourceKey       NVARCHAR(30)
         , @c_PickMethod      NVARCHAR(10)
         , @c_ToID            NVARCHAR(18)
         , @c_ToLoc           NVARCHAR(10)
         , @c_ToLogicalLoc    NVARCHAR(18)
         , @c_SuggestLoc      NVARCHAR(10)
         , @c_UserId          NVARCHAR(30)
         , @c_PickAndDropLOC  NVARCHAR(10)
         , @c_FitCasesInAisle NVARCHAR(1) 
         , @n_PABookingKey    INT          
         , @c_Facility        NVARCHAR(5)
           
   SET @n_StartTCnt     =  @@TRANCOUNT
   SET @n_continue      = 1
   SET @n_NoOfTasks     = 0
   SET @c_TaskDetailKey = ''
   SET @c_Storerkey     = ''
   SET @c_SourceKey     = ''
   SET @c_PickMethod    = ''
   SET @c_ToID          = ''
   SET @c_ToLoc         = ''
   SET @c_ToLogicalLoc  = ''
   SELECT @c_UserId = SUSER_NAME()
   
   IF @n_StartTCnt = 0
      BEGIN TRAN
      	
   /*
   WHILE @@TRANCOUNT > 0
   BEGIN 
      COMMIT TRAN
   END
   */

   DECLARE CursorASNDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
   SELECT RD.Storerkey
         ,RD.ReceiptKey
         ,'FP'
         ,RD.ToID
         ,RD.ToLoc
         ,ISNULL(LOC.LogicalLocation,'')
         ,LOC.Facility
   FROM ReceiptDetail RD WITH (NOLOCK)
   JOIN LOC LOC  WITH (NOLOCK) ON (RD.Toloc = LOC.Loc)
   WHERE RD.ReceiptKey = @c_ReceiptKey
   AND   RD.FinalizeFlag = 'Y'
   AND   RD.QtyReceived > 0
   AND   ISNULL(RD.ToID,'') <> ''
   AND   NOT EXISTS (SELECT 1 FROM TASKDETAIL WITH (NOLOCK) 
                     WHERE SourceKey = RD.ReceiptKey
                     AND FromID = RD.ToID
                     AND TaskType = 'PAF'
                     AND SourceType = 'ispPARL04'
                     AND Storerkey = RD.Storerkey)
   GROUP BY RD.Storerkey
         ,  RD.ReceiptKey
         ,  RD.ToID
         ,  RD.ToLoc
         ,  ISNULL(LOC.LogicalLocation,'')
         ,  LOC.Facility

   OPEN CursorASNDetail   

   FETCH NEXT FROM CursorASNDetail INTO @c_Storerkey, @c_SourceKey, @c_PickMethod, @c_ToID, @c_ToLoc, @c_ToLogicalLoc, @c_Facility

   WHILE @@FETCH_STATUS <> -1               
   BEGIN
   	  SET @c_SuggestLoc = ''
   	  SET @n_PABookingKey = 0
   	  
   	  EXEC rdt.rdt_1819ExtPASP12 
           @nMobile          = 0,
           @nFunc            = 0,
           @cLangCode        = '',
           @cUserName        = @c_UserID,
           @cStorerKey       = @c_StorerKey, 
           @cFacility        = @c_Facility, 
           @cFromLOC         = @c_ToLoc,
           @cID              = @c_ToID,
           @cSuggLOC         = @c_SuggestLoc       OUTPUT,
           @cPickAndDropLOC  = @c_PickAndDropLOC   OUTPUT,
           @cFitCasesInAisle = @c_FitCasesInAisle  OUTPUT,
           @nPABookingKey    = @n_PABookingKey     OUTPUT, 
           @nErrNo           = @n_Err              OUTPUT,
           @cErrMsg          = @c_ErrMsg           OUTPUT
                   	  
      /*EXEC nspRDTPASTD
           @c_userid          = @c_UserID
         , @c_storerkey       = @c_StorerKey
         , @c_lot             = ''
         , @c_sku             = ''
         , @c_id              = @c_ToID
         , @c_fromloc         = @c_ToLoc
         , @n_qty             = 0
         , @c_uom             = '' -- not used
         , @c_packkey         = '' -- optional, if pass-in SKU
         , @n_putawaycapacity = 0
         , @c_final_toloc     = @c_SuggestLoc      OUTPUT
         , @c_Param1          = @c_Receiptkey
         , @c_Param2          = 'ispPARL04'*/

      EXECUTE nspg_GetKey
             'TaskDetailKey'
            ,10 
            ,@c_TaskDetailKey OUTPUT 
            ,@b_success       OUTPUT 
            ,@n_err           OUTPUT 
            ,@c_errmsg        OUTPUT

      IF NOT @b_success = 1
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 30101
         SET @c_Errmsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+': Error Getting New TaskDetailKey. (ispPARL04)' 
         GOTO QUIT_SP
      END   
      
      IF ISNULL(@c_SuggestLoc,'') <> '' AND ISNULL(@n_PABookingKey,0) = 0
      BEGIN       
      	SET @n_PABookingKey = 0
        EXEC rdt.rdt_Putaway_PendingMoveIn 
             @cUserName = @c_UserId
            ,@cType = 'LOCK'
            ,@cFromLoc = @c_ToLoc
            ,@cFromID = @c_ToID
            ,@cSuggestedLOC = @c_SuggestLoc
            ,@cStorerKey = @c_Storerkey
            ,@nErrNo = @n_Err OUTPUT
            ,@cErrMsg = @c_Errmsg OUTPUT
            ,@cTaskDetailKey = @c_TaskDetailKey
            ,@nFunc = 0
            ,@nPABookingKey = @n_PABookingKey OUTPUT

            IF @n_Err <> 0 
            BEGIN
               SET @n_Continue = 3
            END                            
      END                  

      IF ISNULL(@c_SuggestLoc,'') = ''
      BEGIN
         SET @c_SuggestLoc = @c_ToLoc
      END
   	
      INSERT INTO TASKDETAIL 
             (    TaskDetailKey
               ,  Storerkey
               ,  TaskType
               ,  Fromloc
               ,  LogicalFromLoc 
               ,  FromID
               ,  PickMethod
               ,  ToLoc
               ,  LogicalToLoc
               ,  Status
               ,  Priority
               ,  SourcePriority
               ,  SourceType
               ,  SourceKey               
             )  
      VALUES (    @c_TaskdetailKey
               ,  @c_Storerkey
               ,  'PAF'
               ,  @c_Toloc
               ,  @c_ToLogicalLoc
               ,  @c_ToID
               ,  @c_PickMethod
               ,  @c_SuggestLoc
               ,  @c_SuggestLoc
               ,  '0'
               ,  '9'
               ,  '9'
               ,  'ispPARL04'
               ,  @c_Sourcekey
             )

      SET @n_NoOfTasks = @n_NoOfTasks + 1
      FETCH NEXT FROM CursorASNDetail INTO @c_Storerkey, @c_SourceKey, @c_PickMethod, @c_ToID, @c_ToLoc, @c_ToLogicalLoc, @c_Facility
   END
   QUIT_SP:
   CLOSE CursorASNDetail            
   DEALLOCATE CursorASNDetail  

   /*
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
   */

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTCnt
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
      execute nsp_logerror @n_err, @c_errmsg, 'ispPARL04'
      --RAISERROR @n_err @c_errmsg
      RETURN
   END
   ELSE
   BEGIN
      IF @n_NoOfTasks > 0 
      BEGIN
         SET @c_errmsg = 'Total ' +CONVERT(NVARCHAR(5), @n_NoOfTasks)+ ' Putaway From tasks released sucessfully.'
      END
      ELSE
      BEGIN
         SET @c_errmsg = 'No Putaway From tasks released.'
      END

      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO