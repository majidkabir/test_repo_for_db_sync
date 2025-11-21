SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: ispPARL06                                          */  
/* Creation Date: 22-OCT-2019                                           */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-15502 - MY ULM Putaway by pallet id - Release PA Tasks  */  
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
/*            Storerconfig: ASNReleasePATask_SP = 'ispPARL06'           */
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 06-Jul-2022  WLChooi  1.1  WMS-20157 - Add optional param, call by   */
/*                            isp_UNILEVER_AutoReleasePA (WL01)         */
/* 06-Jul-2022  WLChooi  1.1  DevOps Combine Script                     */
/************************************************************************/  

CREATE PROC [dbo].[ispPARL06]
   @c_ReceiptKey        NVARCHAR(10),
   @b_Success           INT OUTPUT, 
   @n_err               INT OUTPUT, 
   @c_errmsg            NVARCHAR(250) OUTPUT,
   @c_ReceiptLineNumber NVARCHAR(5) = ''   --WL01
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
         , @n_PABookingKey    INT
         , @c_PNDLoc          NVARCHAR(10)
         , @c_LOCAisle        NVARCHAR(10)
                
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
            
   WHILE @@TRANCOUNT > 0
   BEGIN 
      COMMIT TRAN
   END   

   DECLARE CursorASNDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
   SELECT RD.Storerkey
         ,RD.ReceiptKey
         ,'FP'
         ,RD.ToID
         ,RD.ToLoc
         ,ISNULL(LOC.LogicalLocation,'')
   FROM ReceiptDetail RD WITH (NOLOCK)
   JOIN LOC LOC  WITH (NOLOCK) ON (RD.Toloc = LOC.Loc)
   WHERE RD.ReceiptKey = @c_ReceiptKey
   AND   RD.FinalizeFlag = 'Y'
   AND   RD.QtyReceived > 0
   AND   ISNULL(RD.ToID,'') <> ''
   AND   ISNULL(RD.PutawayLoc,'') = ''
   AND   NOT EXISTS (SELECT 1 FROM TASKDETAIL WITH (NOLOCK) 
                     WHERE SourceKey = RD.ReceiptKey
                     AND FromID = RD.ToID
                     AND TaskType = 'ASTPA1'
                     AND SourceType = 'ispPARL06'
                     AND Storerkey = RD.Storerkey)
   AND RD.ReceiptLineNumber = CASE WHEN ISNULL(@c_ReceiptLineNumber,'') = '' 
                                   THEN RD.ReceiptLineNumber 
                                   ELSE @c_ReceiptLineNumber END   --WL01
   GROUP BY RD.Storerkey
         ,  RD.ReceiptKey
         ,  RD.ToID
         ,  RD.ToLoc
         ,  ISNULL(LOC.LogicalLocation,'')

   OPEN CursorASNDetail   

   FETCH NEXT FROM CursorASNDetail INTO @c_Storerkey, @c_SourceKey, @c_PickMethod, @c_ToID, @c_ToLoc, @c_ToLogicalLoc

   WHILE @@FETCH_STATUS <> -1               
   BEGIN
      SET @c_SuggestLoc = ''
      SET @n_PABookingKey = 0
      SET @c_PNDLoc = ''
      SET @c_LOCAisle = ''
                
      EXEC nspRDTPASTD
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
         , @c_Param2          = 'ispPARL06'
        
      IF ISNULL(@c_SuggestLoc,'') = ''
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 30110
         SET @c_Errmsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+': Unable to find PA location for Receiptkey: '   --WL01 
                       + TRIM(@c_SourceKey) + '. (ispPARL06)'   --WL01 
         --GOTO QUIT_SP
      END      
        
      IF ISNULL(@c_SuggestLoc,'') <> ''
      BEGIN                 
         SELECT @c_LOCAisle = LOCAisle FROM LOC WITH (NOLOCK) WHERE LOC = @c_SuggestLoc
         
         SELECT TOP 1 @c_PNDLoc = Code
         FROM CODELKUP (NOLOCK)
         WHERE ListName = 'PND'
         AND StorerKey = @c_StorerKey
         AND Code2 = @c_LOCAisle
                  
         IF ISNULL(@c_PNDLoc,'') = ''
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 30130
            SET @c_Errmsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+': Unable to find PND location for Receiptkey: '   --WL01 
                          + TRIM(@c_SourceKey) + ' LocAisle: ' + TRIM(@c_LOCAisle)  + '. (ispPARL06)'   --WL01 
            --GOTO QUIT_SP
         END              

         IF ISNULL(@c_PNDLoc,'') <> '' 
         BEGIN       
            BEGIN TRAN
                
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
              SET @n_Err = 30120
              SET @c_Errmsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+': Error Getting New TaskDetailKey. (ispPARL06)' 
              GOTO QUIT_SP
           END   

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
               GOTO QUIT_SP
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
                     ,  FinalLOC
                     ,  Status
                     ,  Priority
                     ,  SourcePriority
                     ,  SourceType
                     ,  SourceKey
                   )  
            VALUES (    @c_TaskdetailKey
                     ,  @c_Storerkey
                     ,  'ASTPA1'
                     ,  @c_Toloc
                     ,  @c_ToLogicalLoc
                     ,  @c_ToID
                     ,  @c_PickMethod
                     ,  @c_PNDLoc
                     ,  @c_PNDLoc
                     ,  @c_SuggestLoc
                     ,  '0'
                     ,  '9'
                     ,  '9'
                     ,  'ispPARL06'
                     ,  @c_Sourcekey
                   )
                                                   
            UPDATE RECEIPTDETAIL WITH (ROWLOCK)
            SET PutawayLoc = @c_SuggestLoc
               ,Trafficcop = NULL
               ,editwho = SUSER_SNAME()
               ,editdate = GETDATE()
            WHERE Receiptkey = @c_Receiptkey         
            AND ToID = @c_ToID
            AND ToLoc = @c_ToLoc
            
            SET @n_NoOfTasks = @n_NoOfTasks + 1         

            WHILE @@TRANCOUNT > 0
            BEGIN 
               COMMIT TRAN
            END                                    
         END                  
      END   

      FETCH NEXT FROM CursorASNDetail INTO @c_Storerkey, @c_SourceKey, @c_PickMethod, @c_ToID, @c_ToLoc, @c_ToLogicalLoc
   END
   QUIT_SP:
   CLOSE CursorASNDetail            
   DEALLOCATE CursorASNDetail
     
   WHILE @@TRANCOUNT > 0
   BEGIN 
      COMMIT TRAN
   END     
               
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END   

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
      execute nsp_logerror @n_err, @c_errmsg, 'ispPARL06'
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