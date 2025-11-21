SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: mspPKD01                                                */
/* Creation Date: 2024-11-22                                            */
/* Copyright: Maersk Logistics                                          */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: FCR-1430 - Update Tasks When system Move and Swap Lot & ID  */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 8.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2024-11-22  Wan      1.0   Created.                                  */
/************************************************************************/
CREATE   PROC mspPKD01   
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
     
   DECLARE @n_Continue           INT = 1 
         , @n_StartTCnt          INT = @@TRANCOUNT
         
         , @n_Qty_Ins            INT          = 0
         , @n_Qty_Del            INT          = 0
         , @n_Qty_Task           INT          = 0
         , @c_Lot_Ins            NVARCHAR(10) = ''
         , @c_Loc_Ins            NVARCHAR(10) = ''
         , @c_ID_Ins             NVARCHAR(18) = ''
         , @c_Lot_Del            NVARCHAR(10) = ''
         , @c_Loc_Del            NVARCHAR(10) = ''
         , @c_ID_Del             NVARCHAR(18) = ''
         , @c_TaskDetailKey      NVARCHAR(10) = ''
         , @c_NewTaskDetailKey   NVARCHAR(10) = ''
   
         , @CUR_UPDTASK   CURSOR

   SET @b_Success = 1
   SET @n_Err = 0
   SET @c_ErrMsg = '' 

   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END   
   
   IF @c_Action = 'UPDATE'    
   BEGIN
      SET @CUR_UPDTASK = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT I.Storerkey
            ,I.Lot, I.Loc, I.ID
            ,D.Lot, D.Loc, D.ID
            ,I.Qty, D.Qty, TD.Qty
            ,TD.TaskDetailKey
      FROM #INSERTED I    
      JOIN #DELETED D ON I.Pickdetailkey = D.Pickdetailkey  
      JOIN SKUxLOC sl (NOLOCK) ON sl.StorerKey = I.Storerkey
                              AND sl.Sku = I.Sku
                              AND sl.Loc = I.Loc
                              AND sl.LocationType = 'CASE'
      JOIN LOTxLOCxID lli (NOLOCK) ON  lli.lot = d.lot
                                   AND lli.loc = d.loc
                                   AND lli.Id  = d.Id
      JOIN TASKDETAIL TD (NOLOCK) ON TD.Taskdetailkey = I.TaskdetailKey
      WHERE I.Storerkey = @c_Storerkey  
      AND I.[Status] < '5' 
      AND I.UOM IN ('2', '3')
      AND I.TaskDetailKey = D.TaskDetailKey
      AND I.TaskDetailKey <> ''
      AND I.Loc = D.Loc
      AND ((I.Lot <> D.Lot) OR
           (I.ID  <> D.ID)  OR
           (I.Qty <> D.Qty)
          )
      AND TD.TaskType  = 'FCP'
      AND TD.[Status]  NOT IN ('X','9')  
      AND (lli.Qty - lli.QtyPicked = 0 OR lli.Qty = 0)
      ORDER BY TD.Taskdetailkey, d.Lot, d.Loc, d.ID
               
      OPEN @CUR_UPDTASK

      FETCH NEXT FROM @CUR_UPDTASK INTO @c_Storerkey 
                                       ,@c_Lot_Ins, @c_Loc_Ins, @c_ID_Ins
                                       ,@c_Lot_Del, @c_Loc_Del, @c_ID_Del
                                       ,@n_Qty_Ins, @n_Qty_Del, @n_Qty_Task
                                       ,@c_TaskDetailKey

      WHILE @@FETCH_STATUS <> -1 AND @n_Continue = 1
      BEGIN 
         -- UPDATE Taskdetail set Qty 
         IF @n_Qty_Ins <= @n_Qty_Del
         BEGIN
            IF @n_Qty_Task = @n_Qty_Ins AND (@c_Lot_Ins <> @c_Lot_Del OR @c_ID_Ins <> @c_ID_Del)
            BEGIN
               UPDATE TASKDETAIL WITH (ROWLOCK)
                  SET Lot    = @c_Lot_Ins
                     ,FromID = @c_ID_Ins
                     ,Trafficcop = NULL
                     ,EditWho    = SUSER_SNAME()
                     ,EditDate   = GETDATE()
               WHERE TaskDetailKey = @c_TaskDetailkey
        
               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3
               END
            END
            ELSE IF @n_Qty_Task > @n_Qty_Ins AND @c_Lot_Ins = @c_Lot_Del OR @c_ID_Ins = @c_ID_Del
            BEGIN
               UPDATE TASKDETAIL WITH (ROWLOCK)
                  SET Qty = Qty - @n_Qty_Ins
                     ,SystemQty = SystemQty - @n_Qty_Ins
                     ,Trafficcop = NULL
                     ,EditWho    = SUSER_SNAME()
                     ,EditDate   = GETDATE()
               WHERE TaskDetailKey = @c_TaskDetailkey
        
               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 86010    
                  SET @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update TaskDetail Failed. (mspPKD01)'   
               END

               IF @n_Continue = 1
               BEGIN
                  -- INSERT New Task base with new: Lot = @c_Lot_Ins, FromID = @c_ID_Ins, taskdetail.qty = @n_Qty_Ins
                  SET @b_Success = 0  
                  EXECUTE dbo.nspg_Getkey
                      @KeyName     ='TaskDetailKey'
                     ,@fieldlength = 10
                     ,@keystring   = @c_NewTaskDetailKey OUTPUT
                     ,@b_Success   = @b_success          OUTPUT
                     ,@n_err       = @n_err              OUTPUT
                     ,@c_errmsg    = @c_errmsg           OUTPUT
            
                  IF @b_success = 0
                  BEGIN
                     SET @n_continue = 3
                  END
               END

               IF @n_Continue = 1
               BEGIN
                  INSERT INTO TASKDETAIL    
                     (    
                     TaskDetailKey    
                     ,TaskType         
                     ,Storerkey        
                     ,Sku              
                     ,Lot              
                     ,UOM              
                     ,UOMQty           
                     ,Qty              
                     ,FromLoc          
                     ,LogicalFromLoc   
                     ,FromID           
                     ,ToLoc            
                     ,LogicalToLoc     
                     ,ToID             
                     ,Caseid           
                     ,PickMethod       
                     ,[Status]          
                     ,StatusMsg        
                     ,[Priority]         
                     ,SourcePriority   
                     ,Holdkey          
                     ,UserKey          
                     ,UserPosition     
                     ,UserKeyOverRide  
                     ,StartTime        
                     ,EndTime          
                     ,SourceType       
                     ,SourceKey        
                     ,PickDetailKey    
                     ,OrderKey         
                     ,OrderLineNumber  
                     ,ListKey          
                     ,WaveKey          
                     ,ReasonKey        
                     ,Message01        
                     ,Message02        
                     ,Message03        
                     ,SystemQty        
                     ,RefTaskKey       
                     ,LoadKey          
                     ,AreaKey          
                     ,DropID           
                     ,TransitCount     
                     ,TransitLOC       
                     ,FinalLOC         
                     ,FinalID          
                     ,Groupkey       
                     ,QtyReplen    
                     ,PendingMoveIn          
                     )    
                  SELECT  
                     @c_NewTaskDetailKey    
                    ,td.TaskType         
                    ,td.Storerkey        
                    ,td.Sku              
                    ,@c_Lot_Ins            
                    ,td.UOM              
                    ,td.UOMQty           
                    ,@n_Qty_Ins            
                    ,td.FromLoc         
                    ,td.LogicalFromLoc   
                    ,@c_ID_Ins           
                    ,td.ToLoc            
                    ,td.LogicalToLoc     
                    ,@c_ID_Ins            
                    ,td.Caseid           
                    ,td.PickMethod       
                    ,td.[Status]           
                    ,td.StatusMsg        
                    ,td.[Priority]         
                    ,td.SourcePriority   
                    ,td.Holdkey          
                    ,td.UserKey          
                    ,td.UserPosition     
                    ,td.UserKeyOverRide  
                    ,td.StartTime        
                    ,td.EndTime          
                    ,td.SourceType       
                    ,td.SourceKey        
                    ,td.PickDetailKey    
                    ,td.OrderKey         
                    ,td.OrderLineNumber  
                    ,td.ListKey          
                    ,td.WaveKey          
                    ,td.ReasonKey        
                    ,td.Message01        
                    ,td.Message02        
                    ,td.Message03        
                    ,@n_Qty_Ins       
                    ,td.RefTaskKey       
                    ,td.LoadKey          
                    ,td.AreaKey          
                    ,td.DropID           
                    ,td.TransitCount     
                    ,td.TransitLOC       
                    ,td.FinalLOC         
                    ,@c_ID_Ins        
                    ,td.Groupkey                
                    ,0 
                    ,0  
                  FROM TASKDETAIL td (NOLOCK)
                  WHERE TaskDetailKey = @c_TaskDetailkey

                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_Continue = 3
                     SET @n_Err = 86020    
                     SET @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Insert TaskDetail Failed. (mspPKD01)'    
                  END
               END
            END
         END
         FETCH NEXT FROM @CUR_UPDTASK INTO @c_Storerkey 
                                          ,@c_Lot_Ins, @c_Loc_Ins, @c_ID_Ins
                                          ,@c_Lot_Del, @c_Loc_Del, @c_ID_Del
                                          ,@n_Qty_Ins, @n_Qty_Del, @n_Qty_Task
                                          ,@c_TaskDetailKey
      END 
      CLOSE @CUR_UPDTASK
      DEALLOCATE @CUR_UPDTASK
   END          
      
   QUIT_SP:
   
   IF OBJECT_ID('tempdb..#DELETED_ID') IS NOT NULL
   BEGIN
      DROP TABLE #DELETED_ID
   END

    IF @n_Continue=3  -- Error Occured - Process AND Return
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
       EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'mspPKD01'     
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