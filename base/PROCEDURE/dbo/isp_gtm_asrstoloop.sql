SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store Procedure:  isp_GTM_ASRSToLoop                                 */  
/* Creation Date: 16 Aug 2015                                           */  
/* Copyright: LFL                                                       */  
/* Written by: TKLIM                                                    */  
/*                                                                      */  
/* Purpose: Query, Calculate and Callout pallet to GTMLoop              */  
/*                                                                      */  
/* Input Parameters:  @c_Storerkey     - Define by Client               */  
/*                    @c_DataStream    - Data Stream Code               */  
/*                    @b_debug         - 1= Yes; 0 = No                 */  
/*                                                                      */  
/* Output Parameters: @b_Success       - Success Flag  = 0              */  
/*                    @n_err           - Error Code    = 0              */  
/*                    @c_errmsg        - Error Message = ''             */  
/*                                                                      */  
/* Usage: Assign WS to task for pallet to be Callout to GTM             */  
/*                                                                      */  
/* Called By: SQL Job                                                   */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/* 16-Aug-2015  TKLIM     1.0   Initial                                 */  
/*                              Change the ARSR to Loop Call out        */  
/* 19-Jul_2016  Barnett         logic no need to use WS(BL01)           */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_GTM_ASRSToLoop]   
        @b_Success         INT            OUTPUT    
      , @n_err             INT            OUTPUT      
      , @c_ErrMsg          NVARCHAR(215)  OUTPUT    
      , @b_debug           INT = 0    
  
AS  
BEGIN  
   SET NOCOUNT ON       
   SET ANSI_NULLS OFF    
   SET ANSI_WARNINGS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF   
  
  
   /*********************************************/  
   /* Variables Declaration (Start)             */  
   /*********************************************/  
   --Variables  
   DECLARE @n_continue        INT  
  
   DECLARE @n_ActiveWS        INT  
         , @n_MaxPltInGTMArea INT  
         , @n_MaxPltInWS      INT  
         , @n_MaxPltPerWS     INT  
         , @c_WS              NVARCHAR(1)  
         , @n_Counter         INT  
         , @n_WSPltCount      INT  
         , @n_PltInGTMArea    INT  
          
   DECLARE @n_SeqNo           INT  
         , @c_OrderKey        NVARCHAR(10)  
         , @c_TaskDetailKey   NVARCHAR(10)  
         , @c_PalletID        NVARCHAR(18)  
         , @c_Priority        NVARCHAR(1)  
  
   DECLARE @c_TASK_ASRSMV     NVARCHAR(10)  
         , @c_TYPE_SEND       NVARCHAR(10)  
         , @c_LOC_GTMLoop     NVARCHAR(10)  
  
   /*********************************************/  
   /* Variables Defaults (Start)             */  
   /*********************************************/  
   SET @n_continue         = 1  
  
   SET @n_ActiveWS         = 0  
   SET @n_MaxPltInGTMArea  = 0  
   SET @n_MaxPltInWS       = 0  
   SET @n_MaxPltPerWS = 0  
   SET @c_WS               = ''  
   SET @n_Counter          = 0  
   SET @n_WSPltCount       = 0  
   SET @n_PltInGTMArea     = 0  
  
   SET @n_SeqNo            = 0  
   SET @c_OrderKey         = ''  
   SET @c_TaskDetailKey    = ''  
   SET @c_PalletID         = ''  
   SET @c_Priority         = '5'  
  
   SET @c_TASK_ASRSMV      = 'MOVE'  
   SET @c_TYPE_SEND        = 'SEND'  
   SET @c_LOC_GTMLoop      = 'GTMLoop'  
  
   --Get Status for all Stations to see which station turned On     
   SELECT @n_ActiveWS =Count(1)  
   FROM Codelkup GTM (NOLOCK)   
   WHERE GTM.Listname = 'ASRSGTMWS' AND GTM.UDF03 = '1'  
  
  
   --Get Max Pallet In Loop and Workstation  
   SELECT @n_MaxPltInGTMArea = UDF01, @n_MaxPltInWS = UDF02   
   FROM Codelkup WITH (NOLOCK)   
   WHERE Listname = 'GTMMaxPlt'  
  
   --Calculate Max Pallet Per GTM based on Turned On Station  
   SET @n_MaxPltPerWS  = CAST(@n_MaxPltInGTMArea / @n_ActiveWS AS INT)  
  
   /************************************************************************/  
   /* Update status from 0 to E for Error when pallet LocCategory <> ASRS  */  
   /************************************************************************/  
   UPDATE GTMTask SET WorkStation = '', Status = 'E', ErrMsg = 'Pallet Not In ASRS Location: ' + LLI.LOC  
   FROM GTMTask GT WITH (ROWLOCK)  
   JOIN LOTxLOCxID LLI WITH (NOLOCK)  
   ON LLI.ID = GT.PalletID   
   AND LLI.Qty > 0  
   JOIN LOC LOC WITH (NOLOCK)  
   ON LOC.LOC = LLI.LOC  
   AND (LOC.LocationCategory <> 'ASRS')  
   WHERE GT.Status = '0'  
  
   IF @@ERROR <> 0  
   BEGIN  
      SET @n_continue = 3  
      SET @n_err = 68010  
      SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
                       + ': Update 0 to E in GTMTask failed. (isp_GTM_ASRSToLoop)'  
      GOTO QUIT  
   END  
  
   /************************************************************************/  
   /* Update status from 0 to 1 for pallet already in Loop                 */  
   /************************************************************************/  
   UPDATE GTMTask SET Status = '1', ErrMsg = ''  
   FROM GTMTask GT WITH (ROWLOCK)  
   JOIN GTMLoop GL WITH (NOLOCK)  
   ON GL.PalletID = GT.PalletID  
   WHERE GT.Status = '0'  
  
   IF @@ERROR <> 0  
   BEGIN  
      SET @n_continue = 3  
      SET @n_err = 68011  
      SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
                        + ': Update Status to 1 in GTMTask failed. (isp_GTM_ASRSToLoop)'  
   END  
  
   /******************************************************************/  
   /* Loop Every WorkStation which already turned ON                 */  
   /******************************************************************/  
   --DECLARE C_GTMWS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR --(BL01 no more using this cursor, call out pallet base on seqno only.)  
   --SELECT UDF01 FROM Codelkup WITH (NOLOCK)    
   --WHERE Listname = 'ASRSGTMWS' AND UDF03 = '1'  
   --ORDER BY UDF05 ASC  
  
   --OPEN C_GTMWS    
   --FETCH NEXT FROM C_GTMWS INTO @c_WS  
        
   --WHILE (@@FETCH_STATUS <> -1)       
   --BEGIN  
  
      SET @n_counter = 0  
        
      --Get the first PalletID for this WorkStation based on SeqNo      
      DECLARE C_GTMTask CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
        
      SELECT PalletID  
      FROM GTMTask  WITH (NOLOCK)   
      --WHERE WorkStation = @c_WS AND Status = '0' (BL01)  
    WHERE Status = '0' and PalletId not in (SELECT PalletId FROM GTMLoop (NOLOCK))  
      ORDER BY SeqNo ASC  
  
      OPEN C_GTMTask    
      FETCH NEXT FROM C_GTMTask INTO @c_PalletID  
        
      WHILE (@@FETCH_STATUS <> -1)       
      BEGIN  
  
         SET @n_counter = @n_counter + 1  
  
         --Calculate Pallet assigned to the WorkStation   
         --SELECT @n_WSPltCount = PltOTW2Loop + PltInLoop + PltInWS --   (BL01 NO NEED CALCULATE ANYMORE)  
         --FROM V_GTM_PalletCount (NOLOCK)  
         --WHERE WorkStation = @c_WS  
  
         --Calculate Pallet in whole GTM area  
         SELECT @n_PltInGTMArea = SUM(PltOTW2Loop + PltInLoop + PltInWS)  
         FROM V_GTM_PalletCount (NOLOCK)  
         --WHERE WorkStation <> ''  
  
         --In every loop, Break from while loop when if WorkStation pallet count has hit the max.  
         --IF @n_WSPltCount >= @n_MaxPltPerWS OR @n_PltInGTMArea >= @n_MaxPltInGTMArea (BL01)  
   IF /*@n_WSPltCount >= @n_MaxPltPerWS OR*/ @n_PltInGTMArea >= @n_MaxPltInGTMArea  
         BEGIN  
            BREAK  
         END  
  
         /******************************************************************/  
         /* Query required details for Call Out Message                    */  
         /******************************************************************/  
         SELECT TOP 1 @n_SeqNo         = SeqNo  
                    , @c_TaskDetailKey = TaskDetailKey  
                    , @c_Priority      = Priority  
                    , @c_OrderKey      = OrderKey  
         FROM GTMTask WITH (NOLOCK)  
         WHERE PalletID = @c_PalletID   
         --AND WorkStation = @c_WS --(BL01)  
         AND Status = '0'   
         ORDER BY SeqNo ASC  
  
         --BEGIN TRAN here to update everything and COMMIT when WCS return ACK success for MOVE message.   
         --Else ROLLBACK all updates from this point.  
         BEGIN TRAN   
  
         UPDATE TaskDetail WITH (ROWLOCK) SET Status = '1', EditDate = GETDATE(), EditWho = SUSER_SNAME(), TrafficCop=NULL   
         WHERE TaskDetailKey = @c_TaskDetailKey   
         AND FromID = @c_PalletID   
         AND Status = '0'  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @n_continue = 3  
            SET @n_err = 68012  
            SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
                              + ': Update Status to 1 in TaskDetail failed. (isp_GTM_ASRSToLoop)'  
            GOTO NEXTPALLET  
         END  
  
         UPDATE GTMTask WITH (ROWLOCK) SET Status = '1', ErrMsg = ''  
         WHERE TaskDetailKey = @c_TaskDetailKey   
         AND PalletID = @c_PalletID   
         --AND WorkStation = @c_WS --(BL01)  
         AND Status = '0'  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @n_continue = 3  
            SET @n_err = 68013  
            SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
                              + ': Update Status to 1 in GTMTask failed. (isp_GTM_ASRSToLoop)'  
            GOTO NEXTPALLET  
         END  
                   
         INSERT INTO GTMLoop (PalletID, TaskDetailKey, Status, WorkStation, OrderKey, [Priority], AddWho, AddDate, SourceType)  
         VALUES (@c_PalletID, '', '0', '', '' , '', System_user,  Getdate(), 'isp_GTM_ASRSToLoop')  
           
         IF @@ERROR <> 0  
         BEGIN  
            SET @n_continue = 3  
            SET @n_err = 68014  
            SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
                              + ': Update Status to 1 in GTMLoop failed. (isp_GTM_ASRSToLoop)'  
            GOTO NEXTPALLET  
         END  
  
         IF @b_Debug = '1'  
         BEGIN  
            INSERT INTO GTMLog (PalletId, TaskDetailKey, MsgType, FromLoc, ToLoc, LogDate, ErrMsg)  
            VALUES ( @c_PalletID, @c_TaskDetailKey, 'isp_GTM_ASRSToLoop', @c_LOC_GTMLoop, @c_WS, getdate(), CONVERT(VARCHAR,@n_Counter))  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @n_continue = 3  
               SET @n_err = 68015  
               SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
                                 + ': INSERT into GTMLog failed. (isp_GTM_ASRSToLoop)'  
               GOTO NEXTPALLET  
            END  
         END  
  
         SET @b_Success = 0  
  
         EXEC isp_TCP_WCS_MsgProcess  @c_MessageName     = @c_TASK_ASRSMV  
                                    , @c_MessageType     = @c_TYPE_SEND  
                                    , @c_PalletID        = @c_PalletID  
                                    , @c_FromLoc         = ''  
                                    , @c_ToLoc           = @c_LOC_GTMLoop  
                                    , @c_Priority        = @c_Priority  
                                    , @c_TaskDetailKey   = @c_TaskDetailKey  
                                    , @b_debug           = @b_debug  
                                    , @b_Success         = @b_Success OUTPUT  
                                    , @n_Err             = @n_Err OUTPUT  
                                    , @c_ErrMsg          = @c_ErrMsg OUTPUT  
  
         IF @b_Success = 1  
         BEGIN  
            --COMMIT when WCS return ACK success for MOVE message.   
            COMMIT TRAN  
         END  
         ELSE  
         BEGIN  
            --Else ROLLBACK  
            ROLLBACK TRAN  
  
            SET @n_continue = 3  
            SET @n_err = 68016  
            SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
                              + ': Execute isp_TCP_WCS_MsgProcess failed for TaskDetail: ' + @c_TaskDetailKey  
                              + '. (isp_GTM_ASRSToLoop)'  
  
            --UPDATE GTMTask status to E to indicate error  
            UPDATE GTMTask WITH (ROWLOCK) SET Status = 'E', ErrMsg = 'WCS CallOut Failed: ' + @c_ErrMsg  
            WHERE TaskDetailKey = @c_TaskDetailKey   
            AND PalletID = @c_PalletID   
            -- AND WorkStation = @c_WS (BL01)  
            AND Status = '0'  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @n_continue = 3  
               SET @n_err = 68017  
               SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
                                 + ': Update Status to E in GTMTask failed. (isp_GTM_ASRSToLoop)'  
            END  
  
  
            INSERT INTO GTMLog (PalletId, TaskDetailKey, MsgType, FromLoc, ToLoc, LogDate, EditBy, ErrCode, ErrMsg)  
            VALUES ( @c_PalletID, @c_TaskDetailKey, 'isp_GTM_ASRSToLoop' , '', @c_LOC_GTMLoop, getdate(), system_User, @n_Err, CONVERT(VARCHAR,@n_Counter) + '->' + @c_ErrMsg)  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @n_continue = 3  
               SET @n_err = 68018  
               SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
                                + ': INSERT into GTMLog failed. (isp_GTM_ASRSToLoop)'  
            END  
  
            GOTO NEXTPALLET  
  
         END  
  
         NEXTPALLET:  
  
         FETCH NEXT FROM C_GTMTask INTO @c_PalletID  
     
      END  
      CLOSE C_GTMTask  
      DEALLOCATE C_GTMTask  
  
   --   FETCH NEXT FROM C_GTMWS INTO @c_WS  
  
   --END  
   --CLOSE C_GTMWS  
   --DEALLOCATE C_GTMWS  
  
  
   QUIT:  
  
   IF CURSOR_STATUS('GLOBAL' , 'C_GTMTask ') in (0 , 1)  
   BEGIN  
      CLOSE C_GTMTask   
      DEALLOCATE C_GTMTask   
   END  
     
  
   --IF CURSOR_STATUS('GLOBAL' , 'C_GTMWS ') in (0 , 1) --(BL01 no more using thie cursor)  
   --BEGIN  
   --   CLOSE C_GTMWS   
   --   DEALLOCATE C_GTMWS   
   --END  
  
END  

GO