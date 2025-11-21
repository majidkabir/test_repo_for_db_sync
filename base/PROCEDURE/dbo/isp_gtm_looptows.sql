SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/********************************************************************************/    
/* Store Procedure:  isp_GTM_LoopToWS                                           */      
/* Creation Date: 16 Aug 2015                                                   */
/* Copyright: LFL                                                               */
/* Written by: TKLIM                                                            */
/*                                                                              */
/* Purpose: Query, Calculate and Assign WorkStation to Task in GTMTask          */
/*                                                                              */
/* Input Parameters:  @c_Storerkey     - Define by Client                       */
/*                    @c_DataStream    - Data Stream Code                       */
/*                    @b_debug         - 1= Yes; 0 = No                         */
/*                                                                              */
/* Output Parameters: @b_Success       - Success Flag  = 0                      */
/*                    @n_err           - Error Code    = 0                      */
/*                    @c_errmsg        - Error Message = ''                     */
/*                                                                              */
/* Usage: Assign WS to task for pallet to be Callout to GTM                     */
/*                                                                              */      
/* Called By: SQL Job                                                           */      
/*                                                                              */      
/* PVCS Version: 1.0                                                            */      
/*                                                                              */      
/* Version: 5.4                                                                 */      
/*                                                                              */      
/* Data Modifications:                                                          */      
/*                                                                              */      
/* Updates:                                                                     */      
/* Date         Author  Ver.  Purposes                                          */      
/* 16-Aug-2015  TKLIM   1.0   Initial                                           */      
/* 30-MAY-2016  Barnett 1.1   Disable the Console pick logic(BL01)              */      
/* 04-APR-2017  Barnett 1.2   FRB-WMS1548 (BL02)                                */      
/* 04-APR-2017  TKLIM   1.3   Use WHILE @@FETCH_STATUS = 0 (TK01)               */   
/* 20-NOv-2020  kocy    1.4   bug fixed ifinite loop on END_C_PalletInGTMLoop   */  
/********************************************************************************/      
      
CREATE PROC [dbo].[isp_GTM_LoopToWS]       
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
      
   DECLARE @c_WSALocation     NVARCHAR(10)      
         , @n_PendingCOut     INT      
         , @n_PltInLoop       INT      
         , @n_PltInWS         INT      
         , @n_PltInWSQ        INT      
         , @n_DistOrdInWS     INT      
         , @c_Sts6OrdKey      NVARCHAR(10)      
         , @c_Sts7OrdKey      NVARCHAR(10)      
      
   DECLARE @n_SeqNo           INT      
         , @c_OrderKey        NVARCHAR(10)      
         , @c_TaskDetailKey   NVARCHAR(10)      
         , @c_PalletID        NVARCHAR(18)      
         , @c_Priority        NVARCHAR(1)      
      
   DECLARE @c_TASK_ASRSMV     NVARCHAR(10)      
         , @c_TYPE_SEND       NVARCHAR(10)      
         , @c_LOC_GTMLoop     NVARCHAR(10)      
         , @c_TaskType        NVARCHAR(20)        
      
   DECLARE @c_PreviousPalletID  NVARCHAR(18)                 
      
   /*********************************************/      
   /* Variables Defaults (Start)                */      
   /*********************************************/      
      
   SET @n_continue         = 1      
      
   SET @n_ActiveWS         = 0      
   SET @n_MaxPltInGTMArea  = 0      
   SET @n_MaxPltInWS       = 0      
   SET @n_MaxPltPerWS      = 0      
   SET @c_WS               = ''      
   SET @n_Counter          = 0      
      
   SET @c_WSALocation      = ''      
   SET @n_PendingCOut      = 0      
   SET @n_PltInLoop        = 0      
   SET @n_PltInWS          = 0      
   SET @n_PltInWSQ         = 0      
   SET @n_DistOrdInWS      = 0      
   SET @c_Sts6OrdKey       = ''      
   SET @c_Sts7OrdKey       = ''      
      
   SET @n_SeqNo            = 0      
   SET @c_OrderKey         = ''      
   SET @c_TaskDetailKey    = ''      
   SET @c_PalletID         = ''      
   SET @c_Priority         = '5'      
      
   SET @c_TASK_ASRSMV      = 'MOVE'      
   SET @c_TYPE_SEND        = 'SEND'      
   SET @c_LOC_GTMLoop      = 'GTMLoop'      
      
   SET @c_PreviousPalletID   = N''      
         
      
   --Get Status for all Stations to see which station turned On      
   --SELECT @n_ActiveWS = CONVERT(INT,GTM1.UDF03) + CONVERT(INT,GTM2.UDF03) + CONVERT(INT,GTM3.UDF03) + CONVERT(INT,GTM4.UDF03)       
   --FROM Codelkup GTM1 (NOLOCK)       
   --JOIN Codelkup GTM2 (NOLOCK) ON GTM2.Listname = GTM1.Listname AND GTM2.UDF01 = '2'      
   --JOIN Codelkup GTM3 (NOLOCK) ON GTM3.Listname = GTM1.Listname AND GTM3.UDF01 = '3'      
   --JOIN Codelkup GTM4 (NOLOCK) ON GTM4.Listname = GTM1.Listname AND GTM4.UDF01 = '4'      
   --WHERE GTM1.Listname = 'ASRSGTMWS' AND GTM1.UDF01 = '1'      
      
   SELECT @n_ActiveWS =Count(1)      
   FROM Codelkup GTM (NOLOCK)       
   WHERE GTM.Listname = 'ASRSGTMWS' AND GTM.UDF03 = '1'      
      
   --Get Max Pallet In Loop and Workstation      
   SELECT @n_MaxPltInGTMArea = UDF01, @n_MaxPltInWS = UDF02       
   FROM Codelkup WITH (NOLOCK)       
   WHERE Listname = 'GTMMaxPlt'      
      
   --Calculate Max Pallet Per GTM based on Turned On Station      
   --SET @n_MaxPltPerWS  = CAST(@n_MaxPltInGTMArea / @n_ActiveWS AS INT)      
      
   IF @b_Debug = '1'      
   BEGIN      
      SELECT @n_MaxPltInGTMArea  [MaxPltInLoop]      
           , @n_MaxPltInWS       [MaxPltInWS]      
           , @n_MaxPltPerWS      [MaxPltPerWS]      
           , @n_ActiveWS         [ActiveWS]      
   END      
      
   /******************************************************************/      
   /* Extract outstanding TaskDetail into GTMTask                    */      
   /******************************************************************/      
   /*      
   DECLARE C_GTMWS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
   SELECT UDF01 FROM Codelkup WITH (NOLOCK)       
   WHERE Listname = 'ASRSGTMWS' AND UDF03 = '1'      
   ORDER BY UDF05 ASC      
      
   OPEN C_GTMWS        
   FETCH NEXT FROM C_GTMWS INTO @c_WS      
            
   WHILE (@@FETCH_STATUS <> -1)           
   BEGIN      
            
      IF @b_Debug = '1'      
      BEGIN      
         SELECT 'NEW WORKSTATION ================================================================'      
      END      
      
      SET @n_Counter = 0      
      
      WHILE 1=1      
      BEGIN      
      
         SET @n_Counter = @n_Counter + 1      
      
         SELECT @c_WSALocation = WSALocation      
               ,@n_PendingCOut = PendingCOut      
               ,@n_PltInLoop   = PltInLoop      
               ,@n_PltInWS     = PltInWS      
               ,@n_PltInWSQ    = PltInWSQ      
               ,@n_DistOrdInWS = DistOrdInWS      
               ,@c_Sts6OrdKey  = Sts6OrdKey      
               ,@c_Sts7OrdKey  = Sts7OrdKey      
         --SELECT *      
         FROM V_GTM_PalletCount WITH (NOLOCK)      
         WHERE WorkStation = @c_WS      
      
      
         IF @b_Debug = '1'      
         BEGIN      
            SELECT 'LOOP'      
             ,@c_WSALocation [WSALocation]      
                  ,@n_PendingCOut [PendingCOut]      
                  ,@n_PltInLoop   [PltInLoop]      
                  ,@n_PltInWS     [PltInWS]      
                  ,@n_PltInWSQ    [PltInWSQ]      
                  ,@n_DistOrdInWS [DistOrdInWS]      
                  ,@c_Sts6OrdKey  [Sts6OrdKey]      
                  ,@c_Sts7OrdKey  [Sts7OrdKey]      
         END      
      
         --Proceed IF Pallet In WS has not hit max count (3) and no pallet in the Loop      
         --Else Break While Loop      
         IF @n_MaxPltInWS <= @n_PltInWS OR @n_PltInLoop = 0      
         BEGIN      
            BREAK      
         END       
         ELSE  --IF @n_MaxPltInWS > @n_PltInWS AND @n_PltInLoop <> 0       
         BEGIN      
      
            SET @c_Orderkey      = ''      
            SET @c_PalletID      = ''      
            SET @c_Priority      = ''      
            SET @c_TaskDetailKey = ''      
      
            /***************************************************************************************************************************/      
            /* ***WARNING*** Logic below will not work when @n_MaxPltInWS > 3                                                          */      
            /* There are 4 Possible Order# for Pallets in WS                                                                           */      
            /* Case  A     AQ1   AQ2   PltInWS  PltInWSQ  DistOrdInWS Notes Action                                                     */      
            /*-------------------------------------------------------------------------------------------------------------------------*/      
            /* 1     --    --    --    0        0         0           Call Any                                                         */      
            /* 2     --    --    #1    1        1         1           Call OrderKey #1                                                 */      
            /* 3     --    #1    --    1        1         1           Call OrderKey #1                                                 */      
            /* 4     #1    --    --    1        0         1           Call OrderKey #1                                                 */      
            /*-------------------------------------------------------------------------------------------------------------------------*/      
            /* 5     --    #1    #1    2        2         1           Call OrderKey #1                                                 */      
            /* 6     #1    #1    --    2        1         1           Call OrderKey #1                                                 */      
            /*-------------------------------------------------------------------------------------------------------------------------*/      
            /* 7     --    #1    #2    2        2         2           Both with status=6. Unable to determine which OrderKey to call   */      
            /* 8     #1    #2    --    2        1         2           Call OrderKey #2                                                 */      
            /*                                                                                                                         */      
            /***************************************************************************************************************************/      
   --BL01 (Start)      
            --IF @n_DistOrdInWS = 1 OR (@n_DistOrdInWS = 2 AND @n_PltInWSQ = 1)       --CASE 2, 3, 4, 5, 6 OR 8      
            --BEGIN      
      
            --   IF @c_Sts6OrdKey <> ''      
            --      SET @c_Orderkey = @c_Sts6OrdKey      
            --   ELSE      
            --      SET @c_Orderkey = @c_Sts7OrdKey      
      
            --END      
            --ELSE IF @n_DistOrdInWS = 2 AND @n_PltInWSQ = 2                          --CASE 7      
            --BEGIN      
            --   BREAK      
            --END      
                  
            IF @c_Sts6OrdKey <> ''      
                SET @c_Orderkey = @c_Sts6OrdKey      
            ELSE      
                SET @c_Orderkey = @c_Sts7OrdKey      
      
   --BL01 (End)      
      
            IF @c_Orderkey <> ''      
            BEGIN      
                     
               --Call pallet based on OrderKey, Excluding pallet maybe already called to other stations      
               SELECT TOP 1 @c_TaskDetailKey = GT.TaskDetailKey, @c_PalletID = GT.PalletID, @c_Priority = GT.Priority      
               FROM GTMTask GT WITH (NOLOCK)      
               JOIN GTMLoop GL WITH (NOLOCK)      
               ON GT.PalletID = GL.PalletID      
               AND GL.WorkStation = ''      
               AND GL.Status = '1'      
               WHERE GT.WorkStation = @c_WS      
               AND GT.Status = '1'      
               AND GT.OrderKey = @c_Orderkey      
               ORDER BY GT.SeqNo ASC      
      
            END      
                  
            IF @c_TaskDetailKey = ''      
            BEGIN                     
               --Call Any Pallet based on SeqNo, Excluding pallet maybe already called to other stations      
               SELECT TOP 1 @c_TaskDetailKey = GT.TaskDetailKey, @c_PalletID = GT.PalletID, @c_Priority = GT.Priority      
               FROM GTMTask GT WITH (NOLOCK)      
               JOIN GTMLoop GL WITH (NOLOCK)      
               ON GT.PalletID = GL.PalletID      
               AND GL.WorkStation = ''       
               AND GL.Status = '1'       
               WHERE GT.WorkStation = @c_WS      
               AND GT.Status = '1'      
               ORDER BY GT.SeqNo ASC      
      
            END      
      
            IF @b_Debug = '1'      
            BEGIN      
               SELECT 'Moving pallet to WS'      
                     ,@c_TaskDetailKey [TaskDetailKey]      
                     ,@c_PalletID      [PalletID]      
                     ,@c_Priority      [Priority]      
                     ,@c_WSALocation   [WSALocation]      
            END      
      
            IF @c_PreviousPalletID = @c_PalletID AND @n_Counter > 3      
            BEGIN      
                  --Quit the while      
                  BREAK      
            END      
      
            IF @c_TaskDetailKey = '' OR @c_PalletID = '' OR @c_Priority = '' OR @c_WSALocation = ''      
            BEGIN      
               SET @n_continue = 3      
               SET @n_err = 68015      
               SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))       
                                + ': TaskDetailKey / PalletID / Priority / WSALocation is Blank (isp_GTM_LoopToWS)'      
               BREAK      
      
            END      
            ELSE      
            BEGIN      
      
               BEGIN TRAN       
      
               UPDATE TaskDetail WITH (ROWLOCK) SET Status = '6', EditDate = GETDATE(), EditWho = SUSER_SNAME(), TrafficCop=NULL       
               WHERE TaskDetailKey = @c_TaskDetailKey       
               AND FromID = @c_PalletID       
               AND Status = '1'      
      
               IF @@ERROR <> 0      
               BEGIN      
                  SET @n_continue = 3      
                  SET @n_err = 68012      
                  SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))      
                                    + ': Update Status to 6 in TaskDetail failed. (isp_GTM_LoopToWS)'      
                  GOTO NEXTPALLET      
               END      
      
               UPDATE GTMTask WITH (ROWLOCK) SET Status = '6', ErrMsg = ''      
               WHERE TaskDetailKey = @c_TaskDetailKey       
               AND PalletID = @c_PalletID       
               AND WorkStation = @c_WS       
               AND Status = '1'      
      
               IF @@ERROR <> 0      
               BEGIN      
                  SET @n_continue = 3      
                  SET @n_err = 68011      
                  SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))      
                                    + ': Update Status to 6 in GTMTask failed. (isp_GTM_LoopToWS)'      
                  GOTO NEXTPALLET      
               END      
      
               UPDATE GTMLoop WITH (ROWLOCK) SET TaskDetailKey   = @c_TaskDetailKey      
                                                , WorkStation    = @c_WS      
                                         , OrderKey       = @c_OrderKey      
                             , Priority       = @c_Priority      
                                                , EditWho        = System_user      
                                                , EditDate       = Getdate()      
                                                , SourceType     = 'isp_GTM_LoopToWS'      
                                                --, Status         = '2'      
               WHERE PalletID = @c_PalletID       
               AND Status = '1'      
      
               IF @@ERROR <> 0      
               BEGIN      
                  SET @n_continue = 3      
                  SET @n_err = 68011      
                  SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))      
                         + ': Update Status to 6 in GTMTask failed. (isp_GTM_LoopToWS)'      
                  GOTO NEXTPALLET      
               END      
      
               IF @b_Debug = '1'      
               BEGIN      
                  INSERT INTO GTMLog (PalletId, TaskDetailKey, MsgType, FromLoc, ToLoc, LogDate, ErrMsg)      
                  VALUES ( @c_PalletID, @c_TaskDetailKey, 'isp_GTM_LoopToWS', @c_LOC_GTMLoop, @c_WS, getdate(), CONVERT(VARCHAR,@n_Counter))      
      
                  IF @@ERROR <> 0      
                  BEGIN      
                     SET @n_continue = 3      
                     SET @n_err = 68013      
                     SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))      
                                       + ': INSERT into GTMLog failed. (isp_GTM_LoopToWS)'      
                     GOTO NEXTPALLET      
                  END      
               END      
      
               SET @b_Success = 0      
      
               EXEC isp_TCP_WCS_MsgProcess  @c_MessageName     = @c_TASK_ASRSMV      
                                          , @c_MessageType     = @c_TYPE_SEND      
                                          , @c_PalletID        = @c_PalletID      
                                          , @c_FromLoc         = ''      
                                          , @c_ToLoc           = @c_WSALocation              
                                          , @c_Priority        = @c_Priority               
                                          , @c_TaskDetailKey   = @c_TaskDetailKey           
                                          , @b_debug           = @b_debug      
                                          , @b_Success         = @b_Success OUTPUT      
                                          , @n_Err             = @n_Err OUTPUT      
                                          , @c_ErrMsg          = @c_ErrMsg OUTPUT      
                          
               IF @b_Success = 1      
               BEGIN      
                  COMMIT TRAN      
               END      
               ELSE      
               BEGIN      
      
                  ROLLBACK TRAN      
      
                  SET @n_continue = 3      
                  SET @n_err = 68010      
                  SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))      
                                    + ': Execute isp_TCP_WCS_MsgProcess failed for TaskDetail: ' + @c_TaskDetailKey + '. (isp_GTM_LoopToWS)'      
                                    + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')      
                        
                  --UPDATE GTMTask WITH (ROWLOCK) SET Status = 'E', ErrMsg = 'WCS CallOut Failed: ' + @c_ErrMsg      
                  --WHERE TaskDetailKey = @c_TaskDetailKey       
                  --AND PalletID = @c_PalletID       
                  --AND WorkStation = @c_WS       
                  --AND Status = '0'      
      
                  --IF @@ERROR <> 0      
                  --BEGIN      
                  --   SET @n_continue = 3      
                  --   SET @n_err = 68011      
                  --   SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))      
                  --                     + ': Update Status to E in GTMTask failed. (isp_GTM_LoopToWS)'      
                  --END      
                   
                INSERT INTO GTMLog (PalletId, TaskDetailKey, MsgType, FromLoc, ToLoc, LogDate, EditBy, ErrCode, ErrMsg)      
                  VALUES ( @c_PalletID, @c_TaskDetailKey, 'isp_GTM_LoopToWS', '', @c_LOC_GTMLoop, getdate(), system_User, @n_Err, CONVERT(VARCHAR,@n_Counter) + '->' + @c_ErrMsg)      
      
                  IF @@ERROR <> 0      
                  BEGIN      
                     SET @n_continue = 3      
                     SET @n_err = 68014      
                     SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))      
                                      + ': INSERT into GTMLog failed. (isp_GTM_LoopToWS)'      
      
                  END      
                       
                  GOTO NEXTPALLET      
      
               END      
            END      
      
         END   --IF @n_MaxPltInWS > @n_PltInWS AND @n_PltInLoop <> 0       
      
         NEXTPALLET:      
      
         --Carry current PalletID to next loop.      
         SELECT @c_PreviousPalletID = @c_PalletID      
      END      --WHILE 1=1      
      
      FETCH NEXT FROM C_GTMWS INTO @c_WS      
      
   END      
   CLOSE C_GTMWS      
   DEALLOCATE C_GTMWS      
   */      
   --Send pallet to WS base on WS priority & availability (BL02)      
   DECLARE C_PalletInGTMLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
      
      SELECT GT.TaskDetailKey, GT.PalletID, GT.TaskType, GT.WorkStation, GT.Priority      
      FROM GTMTask GT WITH (NOLOCK)      
      JOIN GTMLoop GL WITH (NOLOCK) ON GT.PalletID = GL.PalletID AND GL.Status = '1'       
      WHERE GT.Status = '1' AND GT.WorkStation <> ''      
      ORDER BY GT.SeqNo ASC      
                                  
   OPEN C_PalletInGTMLoop        
   FETCH NEXT FROM C_PalletInGTMLoop INTO @c_TaskDetailKey, @c_PalletID, @c_TaskType, @c_WS, @c_Priority      
                                           
   WHILE (@@FETCH_STATUS = 0)       --(TK01)    
   BEGIN      
            
      --If got Same Pallet ID alreadt call to WS, skip.      
      IF EXISTS (SELECT 1 FROM GTMTask (NOLOCK) WHERE PalletID = @c_PalletID AND Status = 6)      
      BEGIN                         
            GOTO NEXTPALLET      
      END      
      
      --If got Same Job in this pallet id not yet complete but different ReftaskKey, skip      
      IF EXISTS (      
                 SELECT 1 FROM TaskDetail (NOLOCK) WHERE FromID = @c_PalletID AND TaskType='GTMJob'       
                  and Status NOT IN ('9','X') and RefTaskKey <> @c_TaskDetailKey      
               )      
      BEGIN      
            GOTO NEXTPALLET      
      END      
      
      
      IF @b_Debug = '1'      
      BEGIN      
         SELECT 'NEW WORKSTATION ================================================================'      
      END      
            
      SET @n_Counter = 0      
            
      --SET @n_Counter = @n_Counter + 1      
      
      IF @c_TaskType NOT IN ('ASRSCC','ASRSQC')      
      BEGIN      
            SET @c_WS = ''      
      
            --Get Workstation from GTMLoop record with lowest pallet count order by WS Priority UDF05      
            SELECT TOP 1 @c_WS = ISNULL(RTRIM(CLK.UDF01),'')      
            FROM Codelkup CLK WITH (NOLOCK)      
            LEFT OUTER JOIN GTMloop GT WITH (NOLOCK)          
            ON GT.WorkStation = CLK.UDF01 --AND GT.Status IN ('Q','0','1','2','6','7')      
            WHERE CLK.ListName = 'ASRSGTMWS'       
            AND CLK.UDF03 = '1'       
            GROUP BY CLK.UDF05, CLK.UDF01      
            HAVING COUNT(GT.PalletID) < @n_MaxPltInWS      
            ORDER BY COUNT(GT.PalletID) ASC, ISNULL(RTRIM(CLK.UDF05),'') ASC      
               
            --If No available WS then end the process      
            IF @c_WS = ''      
            BEGIN                 
               GOTO END_C_PalletInGTMLoop      
            END      
            ELSE      
            BEGIN      
                  --Get The WorkStation LOC Value            
                  SELECT @c_WSALocation = ISNULL(WAL.LOC,'')        
                  FROM CODELKUP CLK (NOLOCK)      
                  LEFT OUTER JOIN LOC WAL WITH (NOLOCK) ON CLK.Code = WAL.PutawayZone AND WAL.LocationCategory = 'ASRSGTM'       
                                                           AND WAL.LogicalLocation = 'A'       
                  WHERE CLK.ListName = 'ASRSGTMWS' AND CLK.UDF01 = @c_WS      
      
            END                        
      END      
      ELSE      
      BEGIN      
            --For ASRSQC & ASRSCC TaskType, send pallet to WorkStation if got slot.      
            SELECT @c_WSALocation = WSALocation      
               ,@n_PendingCOut = PendingCOut      
               ,@n_PltInLoop   = PltInLoop      
               ,@n_PltInWS     = PltInWS      
               ,@n_PltInWSQ    = PltInWSQ      
               ,@n_DistOrdInWS = DistOrdInWS                              
            FROM V_GTM_PalletCount WITH (NOLOCK)      
            WHERE WorkStation = @c_WS      
      
            IF @n_MaxPltInWS <= @n_PltInWS OR @n_PltInLoop = 0      
            BEGIN      
               GOTO NEXTPALLET      
            END       
                             
      END      
      
      BEGIN TRAN      
                     
      --Tag The TaskDetail Status to 6 (Call Pallet to WS)       
      UPDATE TaskDetail WITH (ROWLOCK) SET Status = '6', EditDate = GETDATE(), EditWho = SUSER_SNAME(), TrafficCop=NULL       
      WHERE TaskDetailKey = @c_TaskDetailKey       
      AND FromID = @c_PalletID       
      AND Status = '1'      
      
      IF @@ERROR <> 0      
      BEGIN      
         SET @n_continue = 3      
         SET @n_err = 68012      
         SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))      
                           + ': Update Status to 6 in TaskDetail failed. (isp_GTM_LoopToWS)'      
         GOTO NEXTPALLET      
      END      
      
      --Tag The GTMTask Status to 6 (Call Pallet to WS), and Workstation = avalaible WS.      
      UPDATE GTMTask WITH (ROWLOCK)       
      SET Status = '6', ErrMsg = '', WorkStation = @c_WS       
      WHERE TaskDetailKey = @c_TaskDetailKey       
      AND PalletID = @c_PalletID                      
      AND Status = '1'      
      
      IF @@ERROR <> 0      
      BEGIN      
         SET @n_continue = 3      
         SET @n_err = 68011      
         SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))      
                           + ': Update Status to 6 in GTMTask failed. (isp_GTM_LoopToWS)'      
         GOTO NEXTPALLET      
      END      
      
      --UPDATE the Pallet related information to GTMLoop       
      UPDATE GTMLoop WITH (ROWLOCK) SET TaskDetailKey   = @c_TaskDetailKey      
                                       , WorkStation    = @c_WS      
                                       , OrderKey       = @c_OrderKey      
                                       , Priority       = @c_Priority      
                                       , EditWho        = System_user      
                                       , EditDate       = Getdate()      
                                       , SourceType     = 'isp_GTM_LoopToWS'                                                      
      WHERE PalletID = @c_PalletID       
      AND Status = '1'      
      
      IF @@ERROR <> 0      
      BEGIN      
         SET @n_continue = 3      
         SET @n_err = 68011      
         SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))      
                           + ': Update Status to 6 in GTMTask failed. (isp_GTM_LoopToWS)'      
         GOTO NEXTPALLET      
      END      
      
      IF @b_Debug = '1'      
      BEGIN      
         INSERT INTO GTMLog (PalletId, TaskDetailKey, MsgType, FromLoc, ToLoc, LogDate, ErrMsg)      
         VALUES ( @c_PalletID, @c_TaskDetailKey, 'isp_GTM_LoopToWS', @c_LOC_GTMLoop, @c_WS, getdate(), CONVERT(VARCHAR,@n_Counter))      
      
         IF @@ERROR <> 0      
         BEGIN      
            SET @n_continue = 3      
            SET @n_err = 68013      
            SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))      
                              + ': INSERT into GTMLog failed. (isp_GTM_LoopToWS)'      
            GOTO NEXTPALLET      
         END      
      END      
      
      SET @b_Success = 0      
      
      --Send Move Message to WCS      
      EXEC isp_TCP_WCS_MsgProcess  @c_MessageName     = @c_TASK_ASRSMV      
                          , @c_MessageType     = @c_TYPE_SEND      
                                 , @c_PalletID        = @c_PalletID      
                                 , @c_FromLoc         = ''      
                                 , @c_ToLoc           = @c_WSALocation              
                                 , @c_Priority        = @c_Priority               
                                 , @c_TaskDetailKey   = @c_TaskDetailKey           
                                 , @b_debug           = @b_debug      
                                 , @b_Success         = @b_Success OUTPUT      
                                 , @n_Err             = @n_Err OUTPUT      
                                 , @c_ErrMsg          = @c_ErrMsg OUTPUT      
                          
      IF @b_Success = 1      
      BEGIN      
         COMMIT TRAN      
      END      
      ELSE      
      BEGIN      
      
         ROLLBACK TRAN      
      
         SET @n_continue = 3      
         SET @n_err = 68010      
         SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))      
                           + ': Execute isp_TCP_WCS_MsgProcess failed for TaskDetail: ' + @c_TaskDetailKey + '. (isp_GTM_LoopToWS)'      
                           + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')      
                                          
                   
         INSERT INTO GTMLog (PalletId, TaskDetailKey, MsgType, FromLoc, ToLoc, LogDate, EditBy, ErrCode, ErrMsg)      
         VALUES ( @c_PalletID, @c_TaskDetailKey, 'isp_GTM_LoopToWS', '', @c_LOC_GTMLoop, getdate(), system_User, @n_Err, CONVERT(VARCHAR,@n_Counter) + '->' + @c_ErrMsg)      
      
         IF @@ERROR <> 0      
         BEGIN      
            SET @n_continue = 3      
            SET @n_err = 68014      
            SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))      
                              + ': INSERT into GTMLog failed. (isp_GTM_LoopToWS)'      
      
         END      
                       
         GOTO NEXTPALLET      
      
      END      
      
      
         
      NEXTPALLET:         
             
      FETCH NEXT FROM C_PalletInGTMLoop INTO @c_TaskDetailKey, @c_PalletID, @c_TaskType, @c_WS, @c_Priority      
      
 -- END_C_PalletInGTMLoop:     shall not end here as still within the loop and cause infine loop.  
   
   END      
   CLOSE C_PalletInGTMLoop      
   DEALLOCATE C_PalletInGTMLoop      
      
   END_C_PalletInGTMLoop:    --kocy  
   QUIT:      
  
   --IF CURSOR_STATUS('GLOBAL' , 'C_GTMWS ') in (0 , 1)      
   --BEGIN      
   --   CLOSE C_GTMWS       
   --   DEALLOCATE C_GTMWS       
   --END      
         
   IF CURSOR_STATUS('GLOBAL' , 'C_GTMWS ') in (0 , 1)      
   BEGIN      
      CLOSE C_PalletInGTMLoop       
      DEALLOCATE C_PalletInGTMLoop       
   END      
      
END      

GO