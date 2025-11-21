SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

   
/************************************************************************/
/* Store procedure: isp_TaskDetail_QueueTask_Process                    */
/* Creation Date: 23 Sep 2014                                           */
/* Copyright: IDS                                                       */
/* Written by: TKLIM                                                    */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By: Exceed / RDT                                              */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/
  
CREATE PROCEDURE [dbo].[isp_TaskDetail_QueueTask_Process]  
AS   
BEGIN  
    SET NOCOUNT ON  
    SET ANSI_DEFAULTS OFF    
    SET QUOTED_IDENTIFIER OFF  
    SET CONCAT_NULL_YIELDS_NULL OFF    


    DECLARE  @c_Storerkey                   NVARCHAR(15)  
            ,@c_PickDetailKey               NVARCHAR(10)    
            ,@c_TaskDetailKey               NVARCHAR(10)  
            ,@n_err                         INT  
            ,@c_ErrMsg                      NVARCHAR(250)  
            ,@b_success                     INT  
            ,@n_SourceType                  NVARCHAR(30)  
            ,@n_continue                    INT  
            ,@c_TaskType                    NVARCHAR(30)   

    DECLARE  @c_Sku                         NVARCHAR(20)    
            ,@c_id                          NVARCHAR(18)    
            ,@c_fromloc                     NVARCHAR(10)    
            ,@c_Toloc                       NVARCHAR(10)  
            ,@c_FinalLoc                    NVARCHAR(10)     
            ,@c_PnDLocation                 NVARCHAR(10)    
            ,@n_InWaitingList               INT    
            ,@n_SkuCnt                      INT    
            ,@n_PickQty                     INT    
            ,@c_Status                      NVARCHAR(10)    
            ,@n_PalletQty                   INT    
            ,@n_StartTranCnt                INT    
            ,@c_LaneType                    NVARCHAR(20)    
            ,@c_Priority                    NVARCHAR(10)    
            ,@c_PickTaskType                NVARCHAR(10)    --NJOW01    
            ,@n_CtnPickQty                  INT             --NJOW01    
            ,@c_ToId                        NVARCHAR(18)    --NJOW01    
            ,@c_Lot                         NVARCHAR(10)    --NJOW01    
            ,@c_MasterSku                   NVARCHAR(20)    --NJOW01    
            ,@n_BOMQty                      INT             --NJOW01    
            ,@n_CaseCnt                     INT             --NJOW01    
            ,@n_PickQtyCase                 INT             --NJOW01    
            ,@c_DispatchPalletPickMethod    NVARCHAR(10)    --NJOW05  
            ,@c_OrderKey                    NVARCHAR(20)  


    DECLARE  @c_ExecStatements              NVARCHAR(4000)       
            ,@c_ExecArguments               NVARCHAR(4000)  
            ,@c_MessageName                 NVARCHAR(15)   
            ,@c_MessageType                 NVARCHAR(10)   
            ,@c_OrigMessageID               NVARCHAR(10)   
            ,@c_UD1                         NVARCHAR(20)   
            ,@c_UD2                         NVARCHAR(20)   
            ,@c_UD3                         NVARCHAR(20)   
            ,@c_SerialNo                    INT            
            ,@b_debug                       INT            
            ,@c_MessageGroup                NVARCHAR(20)     
            ,@c_SProcName                   NVARCHAR(100)  
             

    -- Default Parameter  
    SET @c_ExecStatements      = ''   
    SET @c_ExecArguments       = ''  
    SET @c_MessageGroup        = 'WCS'  
    SET @c_MessageName         = 'MOVE'  
    SET @c_StorerKey           = ''  
    SET @c_SProcName           = ''  
    SET @c_OrigMessageID       = ''   
    --SET @c_PalletID            = ''   
    SET @c_FromLoc             = ''   
    SET @c_ToLoc               = ''   
    SET @c_Priority            = ''   
    SET @c_UD1                 = ''   
    SET @c_UD2                 = ''   
    SET @c_UD3                 = ''   
    SET @c_TaskDetailKey       = ''   
    SET @c_SerialNo          = ''   
    SET @b_debug               = '0'  
    SET @b_Success             = '1'  
    SET @n_Err                 = '0'  
    SET @c_ErrMsg              = ''   
    SET @n_SourceType          = 'nspLPRTSK3'  
    SET @c_Sku                 = ''  
    SET @c_Lot                 =''  
    SET @c_FromLoc             =''  


    DECLARE C_FullPalletTask CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
    SELECT  TD.FromId, TD.ToLoc, TD.Priority, TD.TaskDetailKey, TD.TaskType  
    FROM TaskDetail TD WITH (NOLOCK)   
    WHERE TD.Status = 'Q' AND Tasktype IN ('ASRSMV')  

    OPEN C_FullPalletTask    

    FETCH NEXT FROM C_FullPalletTask INTO @c_ID, @c_PnDLocation ,  @c_Priority, @c_TaskDetailKey, @c_TaskType  

    WHILE (@@FETCH_STATUS<>-1)    
    BEGIN    
       
        SELECT @c_FromLoc = LLI.Loc   
        FROM LOTxLOCxID LLI WITH (NOLOCK)  
        JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = LLI.Loc AND LOC.LocationCategory = 'ASRS'  
        WHERE LLI.ID =  @c_id AND Qty > 0  

        IF ISNULL(RTRIM(@c_FromLoc),'') <>''  
        BEGIN  
              

            --Start Call WCS message.    
            EXEC isp_TCP_WCS_MsgProcess    
                  @c_MessageName = @c_MessageName  
                , @c_MessageType = @c_MessageType  
                , @c_OrigMessageID = @c_OrigMessageID  
                , @c_PalletID = @c_id  
                , @c_FromLoc = @c_FromLoc  
                , @c_ToLoc = @c_PnDLocation          
                , @c_Priority = @c_Priority           
                , @c_TaskDetailKey = @c_TaskDetailKey     
                , @b_debug = @b_debug  
                , @b_Success = @b_Success OUTPUT  
                , @n_Err = @n_Err OUTPUT  
                , @c_ErrMsg = @c_ErrMsg OUTPUT  


            INSERT GTMLog (PalletId, TaskDetailKey, MsgType, FromLoc, ToLoc, LogDate, EditBy, ErrCode, ErrMsg)  
            SELECT @c_id, @c_TaskDetailKey, @c_MessageType, @c_FromLoc, @c_ToLoc, getdate(), system_User, @n_Err, @c_ErrMsg  
        

            IF @n_Err <> 0  
            BEGIN  

                SET @n_continue = 3    
                SET @b_Success = 0  
                SET @n_Err = 68009  
                SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                             + ': Fail while executing ' + @c_SProcName + ' (isp_TCP_WCS_MsgProcess) ( '   
                             + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '  
       
                GOTO NEXT_Loop  
            END   

            BEGIN TRANSACTION  
                   
            -- If call Success, Tag Status =1  
            UPDATE TASKDETAIL WITH (ROWLOCK)  
            SET STATUS = 1  
            WHERE TaskDetailKey = @c_TaskDetailKey AND STATUS = 'Q'  


            IF @@ERROR <> 0  
            BEGIN  

                SET @n_continue = 3    
                SET @b_Success = 0  
                SET @n_Err = 68009  
                SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+ ': Update TaskDetail Failed '+ @n_SourceType +')'+   
                            ' ( '+' SQLSvr MESSAGE='+@c_ErrMsg +' ) '  
                GOTO QUIT_SP  
            END   

            COMMIT TRANSACTION  
        END  

        NEXT_Loop:  
       
        FETCH NEXT FROM C_FullPalletTask INTO @c_ID, @c_PnDLocation ,  @c_Priority, @c_TaskDetailKey, @c_TaskType  

    END    
    CLOSE C_FullPalletTask   
    DEALLOCATE C_FullPalletTask    


    QUIT_SP:  

    IF @n_continue= 3  
    BEGIN  
         IF @@TRANCOUNT > @n_StartTranCnt    
         ROLLBACK TRANSACTION  
    END  

END  
  

GO