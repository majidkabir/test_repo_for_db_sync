SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispPARL07                                          */  
/* Creation Date: 19-MAY-2021                                           */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-17015 - TH Triumph Putaway - Release PA Tasks           */  
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
/*            Storerconfig: ASNReleasePATask_SP = 'ispPARL07'           */
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 10-Nov-2021  NJOW     1.0  DEVOPS combine script                     */
/* 04-Sep-2023  NJOW01   1.1  WMS-23577 change logic                    */
/************************************************************************/  

CREATE PROC [dbo].[ispPARL07] 
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
         , @n_PABookingKey    INT          
         , @c_Facility        NVARCHAR(5)
         , @c_Sku             NVARCHAR(20)
         , @n_QtyReceived     INT
         , @c_LocFloor        NVARCHAR(3) 
         , @c_LocBay          NVARCHAR(10) 
         , @c_PALogicalLoc    NVARCHAR(10)
         , @n_PAQty           INT
         , @n_QtyAvailable    INT  --NJOW01
           
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
   
   SELECT @c_Storerkey = Storerkey,
          @c_Facility = Facility
   FROM RECEIPT (NOLOCK)
   WHERE Receiptkey = @c_Receiptkey   
   
   CREATE TABLE #TMP_LOC (Loc NVARCHAR(10),
                          Sku NVARCHAR(20),
                          Qty INT,
                          PendingMoveIn INT,
                          QtyAllocated INT,
                          LocFloor NVARCHAR(3) NULL,
                          LocBay NVARCHAR(10) NULL,
                          PALogicalLoc NVARCHAR(10) NULL)
                    
   INSERT INTO #TMP_LOC (Loc, Sku, Qty, PendingMoveIn, QtyAllocated, LocFloor, LocBay, PALogicalLoc)  --NJOW01
   	  SELECT LOC.Loc, ISNULL(LLI.Sku,''), SUM(ISNULL(LLI.Qty,0) - ISNULL(LLI.QtyAllocated,0) - ISNULL(LLI.QtyPicked,0)) AS Qty, 
   	         0, ---SUM(ISNULL(LLI.PendingMoveIn,0)) AS PendingMoveIn,
   	         SUM(ISNULL(LLI.QtyAllocated,0)),  --NJOW01
   	         LOC.[Floor], LOC.LocBay, LOC.PALogicalLoc
   	  FROM LOC (NOLOCK)
   	  LEFT JOIN LOTXLOCXID LLI (NOLOCK) ON LOC.Loc = LLI.Loc AND (LLI.Qty - LLI.QtyPicked) > 0 AND LLI.Storerkey = @c_Storerkey
   	  --LEFT JOIN LOTXLOCXID LLI (NOLOCK) ON LOC.Loc = LLI.Loc AND ((LLI.Qty - LLI.QtyPicked) + LLI.PendingMoveIn) > 0 AND LLI.Storerkey = @c_Storerkey
   	  WHERE LOC.Status = 'OK'
   	  AND LOC.HostWHCode = 'TRIUMPH'
      AND LOC.LocBay IN (SELECT Code FROM CODELKUP (NOLOCK) WHERE Listname = 'RETBAY') 
      AND LOC.Facility = @c_Facility
      GROUP BY LOC.Loc, LLI.Sku, LOC.[Floor], LOC.LocBay, LOC.PALogicalLoc
      
   DECLARE CursorASNDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
   SELECT RD.Storerkey
         ,RD.ReceiptKey
         ,'FP'
         ,RD.ToID
         ,RD.ToLoc
         ,ISNULL(LOC.LogicalLocation,'')
         ,LOC.Facility
         ,RD.Sku
         ,SUM(RD.QtyReceived) 
   FROM Receipt R WITH (NOLOCK)
   JOIN ReceiptDetail RD WITH (NOLOCK) ON R.Receiptkey = RD.Receiptkey
   JOIN LOC LOC  WITH (NOLOCK) ON (RD.Toloc = LOC.Loc)
   WHERE R.ReceiptKey = @c_ReceiptKey
   AND   RD.FinalizeFlag = 'Y'
   AND   RD.QtyReceived > 0
   AND   ISNULL(RD.ToID,'') <> ''
   AND   R.DocType = 'R'
   AND   NOT EXISTS (SELECT 1 FROM TASKDETAIL WITH (NOLOCK) 
                     WHERE SourceKey = RD.ReceiptKey
                     AND FromID = RD.ToID
                     AND TaskType = 'ASTPA'
                     AND SourceType = 'ispPARL07'
                     AND Storerkey = RD.Storerkey)
   GROUP BY RD.Storerkey
         ,  RD.ReceiptKey
         ,  RD.ToID
         ,  RD.ToLoc
         ,  ISNULL(LOC.LogicalLocation,'')
         ,  LOC.Facility
         ,  RD.Sku 

   OPEN CursorASNDetail   

   FETCH NEXT FROM CursorASNDetail INTO @c_Storerkey, @c_SourceKey, @c_PickMethod, @c_ToID, @c_ToLoc, @c_ToLogicalLoc, @c_Facility, @c_Sku, @n_QtyReceived

   WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)               
   BEGIN      
      SELECT @c_LocFloor = '', @c_LocBay = '', @c_PALogicalLoc = '', @c_SuggestLoc = '', @n_PAQty = 0, @n_QtyAvailable = 0
         	  
      --Find available loc with same sku
      SELECT TOP 1 @c_SuggestLoc = Loc,
                   @n_QtyAvailable = Qty  --NJOW01
      FROM #TMP_LOC
      WHERE Sku = @c_Sku
      AND Qty + PendingMoveIn + QtyAllocated > 0    --NJOW01
      ORDER BY LocFloor, LocBay, Qty+PendingMoveIn+QtyAllocated, PALogicalLoc   --NJOW01
      
      /*--Find empty loc near same sku
      SELECT TOP 1 @c_LocFloor = LocFloor, @c_LocBay = LocBay, @c_PALogicalLoc = PALogicalLoc
      FROM #TMP_LOC 
      WHERE Sku = @c_Sku
      AND (Qty > 0 OR PendingMoveIn > 0)
      ORDER BY LocFloor, LocBay, PALogicalLoc
      
      IF @@ROWCOUNT > 0
      BEGIN
      	  SELECT TOP 1 @c_SuggestLoc = Loc 
      	  FROM #TMP_LOC
      	  WHERE LocFloor >= @c_LocFloor
      	  AND LocBay >= @c_LocBay
      	  AND PALogicalLoc >= @c_PALogicalLoc
      	  AND Qty + PendingMoveIn = 0
      	  ORDER BY LocFloor, LocBay, PALogicalLoc
      END*/
      
      --Find any empty loc      
      IF ISNULL(@c_SuggestLoc,'') = ''
      BEGIN
      	  SET @c_SuggestLoc = 'NOFRIEND'  --NJOW01
      	  /*  --NJOW01 Removed
      	  SELECT TOP 1 @c_SuggestLoc = Loc,
                       @n_QtyAvailable = Qty  --NJOW01      	   
      	  FROM #TMP_LOC
      	  WHERE Qty + PendingMoveIn = 0
      	  ORDER BY LocFloor, LocBay, PALogicalLoc
      	  */
      END      

      --Unable find any empty loc
      IF ISNULL(@c_SuggestLoc,'') = ''
      BEGIN
         --SET @c_SuggestLoc = @c_ToLoc         	  	
         SET @n_Continue = 3
         SET @n_Err = 30110
         SET @c_Errmsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+': Unable find empty loc Sku: ' + RTRIM(@c_Sku) + ' (ispPARL07)'
      END                       
      
      --Found empty loc 
      IF ISNULL(@c_SuggestLoc,'') <> ''
      BEGIN
      	 SET @n_PAQty = @n_QtyReceived
      	 
      	 UPDATE #TMP_LOC
      	 SET PendingMoveIn = PendingMoveIn + @n_PAQty,
      	     Sku = @c_Sku
      	 WHERE Loc = @c_Suggestloc
      END 

      IF @n_PAQty > 0 AND ISNULL(@c_SuggestLoc,'') <> '' 
      BEGIN      	  
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
            SET @n_Err = 30130
            SET @c_Errmsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+': Error Getting New TaskDetailKey. (ispPARL07)' 
         END            	
         
         /*
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
         */                   
                          
         INSERT INTO TASKDETAIL 
                (    TaskDetailKey
                  ,  Storerkey
                  ,  Sku
                  ,  TaskType
                  ,  Fromloc
                  ,  LogicalFromLoc 
                  ,  FromID
                  ,  PickMethod
                  ,  ToLoc
                  ,  LogicalToLoc
                  ,  Status
                  ,  Qty
                  ,  Priority
                  ,  SourcePriority
                  ,  SourceType
                  ,  SourceKey      
                  ,  Message01                
                  ,  Message02
                  ,  Message03
                  ,  SystemQty  --NJOW01
                )  
         VALUES (    @c_TaskdetailKey
                  ,  @c_Storerkey
                  ,  @c_Sku
                  ,  'ASTPA'
                  ,  @c_Toloc
                  ,  @c_ToLogicalLoc
                  ,  @c_ToID
                  ,  @c_PickMethod
                  ,  @c_SuggestLoc
                  ,  @c_SuggestLoc
                  ,  '0'
                  ,  @n_PAQty
                  ,  '9'
                  ,  '9'
                  ,  'ispPARL07'
                  ,  @c_Sourcekey
                  ,  'R'           
                  ,  @c_ToID
                  ,  CAST(@n_PAQty AS NVARCHAR)
                  ,  @n_QtyAvailable  --NJOW01
                )
                
         UPDATE TASKDETAIL WITH (ROWLOCK)
         SET QtyReplen = @n_QtyAvailable,
             TrafficCop = NULL
         WHERE Taskdetailkey = @c_TaskdetailKey
                  
         SET @n_NoOfTasks = @n_NoOfTasks + 1             
      END      	
      
      FETCH NEXT FROM CursorASNDetail INTO @c_Storerkey, @c_SourceKey, @c_PickMethod, @c_ToID, @c_ToLoc, @c_ToLogicalLoc, @c_Facility, @c_Sku, @n_QtyReceived
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
      execute nsp_logerror @n_err, @c_errmsg, 'ispPARL07'
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