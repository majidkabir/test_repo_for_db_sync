SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
   
/************************************************************************/  
/* Store Procedure:  isp_GTM_WSTaskAssignment                           */  
/* Creation Date: 16 Aug 2015                                           */  
/* Copyright: LFL                                                       */  
/* Written by: TKLIM                                                    */  
/*                                                                      */  
/* Purpose: Query, Calculate and Assign WorkStation to Task in GTMTask  */  
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
/* 05-Dec-2015  TKLIM     1.0   Add PickDetail status check (TK01)      */  
/* 18-Dec-2015  TKLIM     1.0   Fix to support PD.Status >= '5' (TK02)  */  
/* 21-Dec-2015  TKLIM     1.0   Default all ASRSPK from AB to BC (TK03) */  
/* 29-Dec-2015  TKLIM     1.0   Default all ASRSTRF from AB to BC (TK04)*/  
/* 23-Feb-2016  BARNETT   1.0   DEL GTMTask.TaskDetailKey not exists in */  
/*                              TaskDteail (BL01)                       */  
/* 24-Feb-2016  BARNETT   1.0   Delete GTMLoop where palletid not exists*/  
/*                              in GTMTask (BL02)                       */  
/* 24-Feb-2016  BARNETT   1.0   Avoid deadlock tuning (BL03)            */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_GTM_WSTaskAssignment]   
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
   Declare @n_continue        INT  
  
   DECLARE @n_ActiveWS        INT  
         , @n_MaxPltInGTMArea INT  
         , @n_MaxPltInWS      INT  
         , @n_MaxPltPerWS     INT  
         , @c_WS              NVARCHAR(1)  
           
         , @n_SeqNo           INT  
         , @c_OrderKey        NVARCHAR(10)  
         , @c_TaskDetailKey   NVARCHAR(10)  
  
   /*********************************************/  
   /* Variables Defaults (Start) */  
   /*********************************************/  
   SET @n_continue     = 1  
  
   SET @n_ActiveWS         = 0  
   SET @n_MaxPltInGTMArea  = 0  
   SET @n_MaxPltInWS       = 0  
   SET @n_MaxPltPerWS      = 0  
  
   SET @n_SeqNo            = 0  
   SET @c_OrderKey         = ''  
   SET @c_TaskDetailKey    = ''  
  
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
   SET @n_MaxPltPerWS  = CAST(@n_MaxPltInGTMArea / @n_ActiveWS AS INT)  
  
   IF @b_Debug = '1'  
   BEGIN  
      SELECT @n_MaxPltInGTMArea  [MaxPltInLoop]  
           , @n_MaxPltInWS       [MaxPltInWS]  
           , @n_MaxPltPerWS      [MaxPltPerWS]  
           , @n_ActiveWS         [ActiveWS]  
   END  
  
   /************************************************************************************/  
   /* Update TaskDetail.Status to 'X' when PickDetail no longer exist or Status >= '5' */  
   /************************************************************************************/  
   --(TK02) - START - Corrected the SELECt and UPDATE statements to support PickDetail.Status >= '5'  
   --IF EXISTS(SELECT 1 FROM TaskDetail TD WITH (NOLOCK)               
   --          WHERE TD.TaskType = 'ASRSPK'  
   --          AND TD.Status IN ('0')  
   --          AND NOT EXISTS(SELECT 1 FROM PickDetail PD WITH (NOLOCK)  
   --                         WHERE PD.TaskDetailKey = TD.TaskDetailKey  
   --                         AND PD.Status < '5'))  --TK01  
   --BEGIN  
   --   UPDATE TaskDetail WITH (ROWLOCK)  
   --   SET Status = 'X', EditDate = GETDATE(), EditWho = SUSER_SNAME(), TrafficCop=NULL   
   --   FROM TaskDetail TD  
   --   LEFT OUTER JOIN PickDetail PD WITH (NOLOCK)  
   --   ON PD.TaskDetailKey = TD.TaskDetailKey   
   --   WHERE TD.TaskType = 'ASRSPK'  
   --   AND TD.Status IN ('0')  
   --   AND (PD.TaskDetailKey IS NULL  
   --   OR PD.Status < '5')  --TK01  
  
   --   IF @@ERROR <> 0  
   --   BEGIN  
   --      SET @n_continue = 3  
   --      SET @n_err = 68000  
   --      SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
   --                       + ': Update Status to X in TaskDetail failed. (isp_GTM_WSTaskAssignment)'  
   --      GOTO QUIT  
   --   END        
   --END  
  
   --(BL02) - BEGIN - Avoid DeadLock tuning, change this part to use cursor to update the record.  
   --IF EXISTS ( SELECT 1 FROM TaskDetail TD WITH (NOLOCK)  
   --            LEFT OUTER JOIN PickDetail PD WITH (NOLOCK)  
   --            ON PD.TaskDetailKey = TD.TaskDetailKey   
   --            WHERE TD.TaskType = 'ASRSPK'  
   --            AND TD.Status = '0'  
   --            AND (PD.TaskDetailKey IS NULL OR PD.Status >= '5') )  
   --BEGIN  
  
   --   UPDATE TaskDetail WITH (ROWLOCK)  
   --   SET Status = 'X', EditDate = GETDATE(), EditWho = SUSER_SNAME(), TrafficCop=NULL   
   --   FROM TaskDetail TD  
   --   LEFT OUTER JOIN PickDetail PD WITH (NOLOCK)  
   --   ON PD.TaskDetailKey = TD.TaskDetailKey   
   --   WHERE TD.TaskType = 'ASRSPK'  
   --   AND TD.Status = '0'  
   --   AND (PD.TaskDetailKey IS NULL OR PD.Status >= '5')  
  
   --   IF @@ERROR <> 0  
   --   BEGIN  
   --      SET @n_continue = 3  
   --      SET @n_err = 68000  
   --      SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
   --                       + ': Update Status to X in TaskDetail failed. (isp_GTM_WSTaskAssignment)'  
   --      GOTO QUIT  
   --   END        
  
   --END  
   DECLARE C_UPDTaskDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
     
      SELECT TD.TaskDetailKey FROM TaskDetail TD WITH (NOLOCK)  
      LEFT OUTER JOIN PickDetail PD WITH (NOLOCK)  
      ON PD.TaskDetailKey = TD.TaskDetailKey   
      WHERE TD.TaskType = 'ASRSPK'  
      AND TD.Status = '0'  
      AND (PD.TaskDetailKey IS NULL OR PD.Status >= '5')  
  
  
   OPEN C_UPDTaskDetail    
   FETCH NEXT FROM C_UPDTaskDetail INTO @c_TaskDetailKey  
        
   WHILE (@@FETCH_STATUS <> -1)       
   BEGIN  
          
      UPDATE TaskDetail WITH (ROWLOCK)  
      SET Status = 'X',   
            EditDate = GETDATE(),   
            EditWho = SUSER_SNAME(),   
            TrafficCop = NULL                    
      WHERE TaskDetailKey = @c_TaskDetailKey        
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @n_continue = 3  
         SET @n_err = 68000  
         SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
                          + ': Update Status to X in TaskDetail failed. (isp_GTM_WSTaskAssignment)'  
         GOTO QUIT  
      END        
  
      FETCH NEXT FROM C_UPDTaskDetail INTO @c_TaskDetailKey  
  
   END  
   CLOSE C_UPDTaskDetail  
   DEALLOCATE C_UPDTaskDetail  
  
  
   --(BL02) - END - Avoid DeadLock tuning, change this part to use cursor to update the record.  
  
   --(TK02) - END - Corrected the SELECt and UPDATE statements to support PickDetail.Status >= '5'  
  
   /************************************************************************/  
   /* Update GTMTask.Status to X when TaskDetail.Status already status X   */  
   /************************************************************************/  
   IF EXISTS(SELECT 1   
             FROM GTMTask GT WITH (NOLOCK)  
             JOIN TaskDetail TD WITH (NOLOCK)  
             ON TD.TaskDetailKey = GT.TaskDetailKey AND TD.Status = 'X'  
             WHERE GT.Status NOT IN ('X','9'))  
   BEGIN  
      UPDATE GTMTask SET WorkStation = '', Status = 'X', ErrMsg = 'TaskDetail Status already X'  
      FROM GTMTask GT WITH (ROWLOCK)  
      JOIN TaskDetail TD WITH (NOLOCK)  
      ON TD.TaskDetailKey = GT.TaskDetailKey   
      AND TD.Status = 'X'  
      WHERE GT.Status NOT IN ('X','9')  
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @n_continue = 3  
         SET @n_err = 68001  
         SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
                          + ': Update 0 to X in GTMTask failed. (isp_GTM_WSTaskAssignment)'  
         GOTO QUIT  
      END        
   END  
  
   /************************************************************************/  
   /* Update GTMTask.Status to 9 when TaskDetail.Status already status 9   */  
   /************************************************************************/  
   IF EXISTS(  SELECT 1  
               FROM GTMTask GT WITH (NOLOCK)  
               JOIN TaskDetail TD WITH (NOLOCK)   
               ON TD.TaskDetailKey = GT.TaskDetailKey AND TD.Status = '9'  
               WHERE GT.Status <> '9')  
   BEGIN  
      UPDATE GTMTask SET WorkStation = '', Status = '9', ErrMsg = 'TaskDetail Status already 9'  
      FROM GTMTask GT WITH (ROWLOCK)  
      JOIN TaskDetail TD WITH (NOLOCK)  
      ON TD.TaskDetailKey = GT.TaskDetailKey   
      AND TD.Status = '9'  
      WHERE GT.Status <> '9'  
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @n_continue = 3  
         SET @n_err = 68002  
         SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
                          + ': Update 0 to 9 in GTMTask failed. (isp_GTM_WSTaskAssignment)'  
         GOTO QUIT  
      END        
   END  
  
   /******************************************************************/  
   /* Delete From GTMTask where Status = '9'                         */  
   /******************************************************************/  
   IF EXISTS(SELECT 1 FROM GTMTask WITH (NOLOCK) WHERE Status IN ('9','X'))  
   BEGIN  
      DELETE FROM GTMTask  
      WHERE Status IN ('9','X')  
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @n_continue = 3  
         SET @n_err = 68003  
         SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
                          + ': DELETE From GTMTask failed. (isp_GTM_WSTaskAssignment)'  
         GOTO QUIT  
      END        
   END  
  
   /*********************************************************************/  
   /* Delete From GTMTask where TaskDetailKey not exists in TaskDetail  */  
   /*********************************************************************/  
   IF EXISTS(SELECT 1  from GTMTask (NOLOCK) -- (BL01) Start  
             WHERE TaskDetailKey NOT IN (SELECT TaskDetailKey from TaskDetail (NOLOCK) WHERE STATUS NOT IN ('X','9')  
             AND GTMTask.Status in('Q','0', 'E'))  
   )  
   BEGIN  
      
      DELETE GTMTask  
      WHERE TaskDetailKey NOT IN (SELECT TaskDetailKey from TaskDetail (NOLOCK) WHERE STATUS NOT IN ('X','9'))   
   AND GTMTask.Status in('Q','0','E','1','7')  
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @n_continue = 3  
         SET @n_err = 68004  
         SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
                          + ': DELETE From GTMTask failed. (isp_GTM_WSTaskAssignment)'  
         GOTO QUIT  
      END        
   END -- (BL01) End  
  
   /*********************************************************************/  
   /* Delete From GTMLoop where PalletID not exists in GTMTask          */  
   /*********************************************************************/  
   IF EXISTS(SELECT 1 FROM GTMLoop (NOLOCK) WHERE PalletId NOT IN (SELECT PalletID from GTMTask (NOLOCK)) ) -- (BL02) Start  
   BEGIN  
      
      DELETE GTMLoop  
      WHERE PalletId NOT IN (SELECT PalletID from GTMTask (NOLOCK))  
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @n_continue = 3  
         SET @n_err = 68005  
         SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
                          + ': DELETE From GTMTask failed. (isp_GTM_WSTaskAssignment)'  
         GOTO QUIT  
      END        
   END -- (BL02) End  
  
     
     
     
  
   /******************************************************************/  
   /* Extract outstanding TaskDetail into GTMTask                    */  
   /******************************************************************/  
   INSERT INTO GTMTask (SeqNo, TaskDetailKey, TaskType, PalletID, Priority, WorkStation, OrderKey, Status, FromLoc, ToLoc, FinalLoc, LogicalFromLoc, LogicalToLoc)  
   SELECT  0                  --SeqNo  
         , TD.TaskDetailKey   --TaskDetailKey  
         , TD.TaskType        --TaskType  
         , TD.FromID          --PalletID  
         , TD.Priority        --Priority  
         , ''                 --WorkStation  
         , TD.OrderKey        --OrderKey  
         , 'Q'                --Status  
         , TD.FromLoc         --FromLoc  
         , TD.ToLoc           --ToLoc  
         , TD.FinalLoc        --FinalLoc  
         , ''                 --LogicalFromLoc  
         , ''                 --LogicalToLoc  
   FROM TaskDetail TD WITH (NOLOCK)  
   LEFT OUTER JOIN GTMTask GT WITH (NOLOCK)   
   ON  GT.TaskDetailKey = TD.TaskDetailKey   
   WHERE TD.TaskType IN ('ASRSPK','ASRSTRF','ASRSQC','ASRSCC')  
   AND TD.STATUS = '0'   
   AND TD.FromID <> ''  
   AND TD.ToLoc = 'GTMLoop'  
   AND GT.TaskDetailKey IS NULL  
   AND TD.AddDate > '2015-08-20 00:00:00.000'  
   ORDER BY TD.Priority, TD.TaskDetailkey  
  
   IF @@ERROR <> 0  
   BEGIN  
      SET @n_continue = 3  
      SET @n_err = 68010  
      SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
                        + ': INSERT into GTMTask failed. (isp_GTM_WSTaskAssignment)'  
   END  
  
   /************************************************************************/  
   /* Reset SeqNo based Priority and TaskDetailKey                         */  
   /************************************************************************/  
   --DECLARE @c_TaskDetailKey NVARCHAR(10),  @n_SeqNo INT  
   DECLARE C_RESETSEQNO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT TaskDetailKey, ROW_NUMBER() OVER (ORDER BY Priority, TaskDetailkey)  
   FROM GTMTask WITH (NOLOCK)  
      
   OPEN C_RESETSEQNO    
   FETCH NEXT FROM C_RESETSEQNO INTO @c_TaskDetailKey, @n_SeqNo  
        
   WHILE (@@FETCH_STATUS <> -1)       
   BEGIN  
  
      IF EXISTS ( SELECT 1 FROM GTMTask WITH (NOLOCK)  
                  WHERE TaskDetailKey = @c_TaskDetailKey   
                  AND SeqNo <> @n_SeqNo)  
      BEGIN  
         UPDATE GTMTask WITH (ROWLOCK)  
         SET SeqNo = @n_SeqNo   
         WHERE TaskDetailKey = @c_TaskDetailKey  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @n_continue = 3  
            SET @n_err = 68011  
            SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
                             + ': Update SeqNo in GTMTask failed. (isp_GTM_WSTaskAssignment)'  
            GOTO QUIT  
         END  
      END  
  
      FETCH NEXT FROM C_RESETSEQNO INTO @c_TaskDetailKey, @n_SeqNo  
  
   END  
   CLOSE C_RESETSEQNO  
   DEALLOCATE C_RESETSEQNO  
     
   /************************************************************************/  
   /* Order Picking task share same SeqNo.                                 */  
   /* Update ASRSPK task SeqNo to Min(SeqNo) Group By OrderKey             */  
   /************************************************************************/  
   --Declare @c_OrderKey NVARCHAR(10) , @n_SeqNo INT  
   DECLARE C_UPDSEQNO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT OrderKey, MIN(SeqNo)   
   FROM GTMTask WITH (NOLOCK)  
   WHERE TaskType = 'ASRSPK' AND ISNULL(RTRIM(OrderKey),'') <> ''  
   GROUP BY OrderKey  
   HAVING MIN(SeqNo) <> MAX(SeqNo)  
  
   OPEN C_UPDSEQNO    
   FETCH NEXT FROM C_UPDSEQNO INTO @c_OrderKey, @n_SeqNo  
        
   WHILE (@@FETCH_STATUS <> -1)       
   BEGIN  
        
      IF EXISTS ( SELECT 1 FROM GTMTask WITH (NOLOCK)  
                  WHERE OrderKey = @c_OrderKey  
                  AND SeqNo <> @n_SeqNo)  
      BEGIN  
         UPDATE GTMTask WITH (ROWLOCK)  
         SET SeqNo = @n_SeqNo  
         WHERE SeqNo <> @n_SeqNo  
         AND OrderKey = @c_OrderKey  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @n_continue = 3  
            SET @n_err = 68012  
            SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
                             + ': Update SeqNo for Order in GTMTask failed. (isp_GTM_WSTaskAssignment)'  
            GOTO QUIT  
         END  
      END  
  
      FETCH NEXT FROM C_UPDSEQNO INTO @c_OrderKey, @n_SeqNo  
  
   END  
   CLOSE C_UPDSEQNO  
   DEALLOCATE C_UPDSEQNO  
  
   /************************************************************************/  
   /* Update status from Q to E for Error when pallet LocCategory <> ASRS  */  
   /************************************************************************/  
   UPDATE GTMTask SET Status = 'E', ErrMsg = 'Pallet Not In ASRS Location: ' + LLI.LOC, EditDate = GETDATE()  
   FROM GTMTask GT WITH (ROWLOCK)  
   JOIN LOTxLOCxID LLI WITH (NOLOCK)  
   ON LLI.ID = GT.PalletID   
   AND LLI.Qty > 0  
   JOIN LOC LOC WITH (NOLOCK)  
   ON LOC.LOC = LLI.LOC  
   AND LOC.LocationCategory <> 'ASRS'  
   WHERE GT.Status = 'Q'  
  
   IF @@ERROR <> 0  
   BEGIN  
      SET @n_continue = 3  
      SET @n_err = 68013  
      SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
                       + ': Update Q to E in GTMTask failed. (isp_GTM_WSTaskAssignment)'  
      GOTO QUIT  
   END  
  
   /************************************************************************/  
   /* Update status from E to Q when pallet is back to LocCategory = 'ASRS */  
   /************************************************************************/  
   UPDATE GTMTask SET Status = 'Q', ErrMsg = '', EditDate = GETDATE()  
   FROM GTMTask GT WITH (ROWLOCK)  
   JOIN LOTxLOCxID LLI WITH (NOLOCK)  
   ON LLI.ID = GT.PalletID   
   AND LLI.Qty > 0  
   JOIN LOC LOC WITH (NOLOCK)  
   ON LOC.LOC = LLI.LOC  
   AND LOC.LocationCategory = 'ASRS'  
   WHERE GT.Status = 'E'  
  
   IF @@ERROR <> 0  
   BEGIN  
      SET @n_continue = 3  
      SET @n_err = 68014  
      SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
                       + ': Update E to Q in GTMTask failed. (isp_GTM_WSTaskAssignment)'  
      GOTO QUIT  
   END  
     
   --/************************************************************************/  
   --/* Update status from E to Q when pallet is back to LocCategory = 'ASRS */  
   --/************************************************************************/  
   --DECLARE C_UPDWS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   --SELECT SeqNo, Orderkey FROM GTMTASK WITH (NOLOCK)    
   --WHERE TaskType = 'ASRSPK'  
   --AND Status NOT IN ('9','X')  
   --GROUP BY SeqNo, Orderkey  
   --HAVING COUNT(DISTINCT WorkStation) > 1  
  
   --OPEN C_UPDWS    
   --FETCH NEXT FROM C_UPDWS INTO @n_SeqNo, @c_Orderkey  
        
   --WHILE (@@FETCH_STATUS <> -1)       
   --BEGIN  
  
   --   SELECT TOP 1 @c_WS = WorkStation  
   --   FROM GTMTASK WITH (NOLOCK)     
   --   WHERE SeqNo = @n_SeqNo  
   --   AND Orderkey = @c_Orderkey  
   --   AND TaskType = 'ASRSPK'  
   --   AND Status NOT IN ('9','X')   
   --   ORDER BY Status DESC  
  
   --   UPDATE GTMTask WITH (ROWLOCK)  
   --   SET WorkStation = @c_WS  
   --   WHERE SeqNo = @n_SeqNo  
   --   AND Orderkey = @c_Orderkey  
   --   AND TaskType = 'ASRSPK'  
   --   AND Status NOT IN ('6','7','9','X')   
   --   AND WorkStation <> @c_WS  
  
   --   IF @@ERROR <> 0  
   --   BEGIN  
   --      SET @n_continue = 3  
   --      SET @n_err = 68015  
   --      SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
   --                       + ': Update WorkStation in GTMTask failed. (isp_GTM_WSTaskAssignment)'  
   --      GOTO QUIT  
   --   END  
  
   --   FETCH NEXT FROM C_UPDWS INTO @n_SeqNo, @c_Orderkey  
  
   --END  
   --CLOSE C_UPDWS  
   --DEALLOCATE C_UPDWS  
     
   /************************************************************************/  
   /* Update PreAssigned Workstation based on TaskDetail.FinalLoc          */  
   /************************************************************************/  
   UPDATE GTMTask SET Workstation = ISNULL(CLK.UDF01,'')  
   FROM GTMTask GT WITH (ROWLOCK)  
   INNER JOIN TaskDetail TD WITH (NOLOCK)  
   ON GT.TaskDetailKey = TD.TaskDetailKey   
   AND TD.FinalLoc NOT IN ('GTMWS','')       --TK01  
   LEFT OUTER JOIN Loc Loc WITH (NOLOCK)  
   ON TD.FinalLoc = Loc.Loc  
   LEFT OUTER JOIN Codelkup CLK WITH (NOLOCK)  
   ON CLK.ListName = 'ASRSGTMWS'   
   AND CLK.Code = Loc.PutawayZone   
   WHERE GT.Status = 'Q'  
   AND GT.Workstation = ''  
  
   IF @@ERROR <> 0  
   BEGIN  
      SET @n_continue = 3  
      SET @n_err = 68016  
      SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
                       + ': Update PreAssigned Workstation on GTMTask failed. (isp_GTM_WSTaskAssignment)'  
      GOTO QUIT  
   END  
  
     
   /******************************************************************************/  
   /* Update LogicalLoc (AB / BC) for TaskType IN ('ASRSTRF','ASRSQC','ASRSCC')  */  
   /******************************************************************************/  
   --UPDATE GTMTask WITH (ROWLOCK)  
   --SET LogicalFromLoc = CASE  WHEN TaskType = 'ASRSTRF' THEN 'A'     
   --                           WHEN TaskType IN ('ASRSQC','ASRSCC','ASRSPK') THEN 'B'   --TK03  
   --                     END,  
  
   --    LogicalToLoc   = CASE  WHEN TaskType = 'ASRSPK' THEN 'C'                        --TK03  
   --                           WHEN TaskType IN ('ASRSQC','ASRSCC','ASRSTRF') THEN 'B'   
   --                     END  
  
   UPDATE GTMTask WITH (ROWLOCK)  
   SET LogicalFromLoc = 'B'   --TK04  
      ,LogicalToLoc   = CASE  WHEN TaskType IN ('ASRSPK','ASRSTRF') THEN 'C'  --TK04  
                              WHEN TaskType IN ('ASRSQC','ASRSCC') THEN 'B'   --TK04  
                        END  
   WHERE TaskType IN ('ASRSPK','ASRSTRF','ASRSQC','ASRSCC')  
   AND LogicalFromLoc = ''  
   AND LogicalToLoc = ''  
  
   IF @@ERROR <> 0  
   BEGIN  
      SET @n_continue = 3  
      SET @n_err = 68017  
      SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
                       + ': Update LogicalLoc in GTMTask failed. (isp_GTM_WSTaskAssignment)'  
      GOTO QUIT  
   END  
  
   --/******************************************************************************/  
   --/* Update LogicalLoc for TaskType IN ('ASRSPK') based on number of pallets    */  
   --/******************************************************************************/  
   --UPDATE GTMTask WITH (ROWLOCK)  
   --SET LogicalFromLoc = CASE WHEN PltCnt = 'S' THEN 'A'  WHEN PltCnt = 'M' THEN 'B' END,  
   --    LogicalToLoc   = CASE WHEN PltCnt = 'S' THEN 'B'  WHEN PltCnt = 'M' THEN 'C' END  
   --FROM GTMTask GT  
   --JOIN (SELECT OrderKey, CASE WHEN Count(PalletID) = 1 THEN 'S'  
   --                            WHEN COUNT(PalletID) > 1 THEN 'M' END [PltCnt]  
   --      FROM GTMTask WITH (NOLOCK)  
   --      WHERE TaskType ='ASRSPK'   
   --      GROUP BY OrderKey  
   --) OP ON OP.OrderKey = GT.OrderKey   
   --AND LogicalFromLoc = ''  
   --AND LogicalToLoc = ''  
  
   --IF @@ERROR <> 0  
   --BEGIN  
   --   SET @n_continue = 3  
   --   SET @n_err = 68018  
   --   SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
   --                    + ': Update LogicalLoc for ASRSPK in GTMTask failed. (isp_GTM_WSTaskAssignment)'  
   --   GOTO QUIT  
   --END  
  
   /******************************************************************/  
   /* Update RefTaskKey when Picking from A to B                     */  
   /* GTMKiosk will show blank screen when this is not done          */  
   /******************************************************************/  
   --UPDATE TaskDetail WITH (ROWLOCK)  
   --SET RefTaskkey = TD.TaskDetailKey , EditDate = GETDATE(), EditWho = SUSER_SNAME(), TrafficCop=NULL   
   --FROM TaskDetail TD  
   --INNER JOIN GTMTask GT WITH (NOLOCK)  
   --ON GT.TaskDetailKey = TD.TaskDetailkey   
   --AND GT.LogicalFromLoc = 'A'   
   --AND GT.LogicalToLoc = 'B'   
   ----WHERE TD.TaskType IN ('ASRSPK','ASRSTRF')     --TK03  
   --WHERE TD.TaskType IN ('ASRSTRF')                --TK03  
   --AND RefTaskkey <> TD.TaskDetailKey  
     
   --IF @@ERROR <> 0  
   --BEGIN  
   --   SET @n_continue = 3  
   --   SET @n_err = 68019  
   --   SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
   --                    + ': Update RefTaskKey in TaskDetail failed. (isp_GTM_WSTaskAssignment)'  
   --   GOTO QUIT  
   --END  
  
   /******************************************************************/  
   /* Sync Updated TaskDetail.Priority into GTMTask.Priority         */  
   /******************************************************************/  
   --Update Priority  
   UPDATE GTMTask WITH (ROWLOCK)  
   SET Priority = TD.Priority  
   FROM GTMTask GT  
   INNER JOIN TaskDetail TD WITH (NOLOCK)  
   ON GT.TaskDetailKey = TD.TaskDetailkey   
   WHERE GT.Priority <> TD.Priority   
   AND TD.Status <> '9'  
   AND GT.Status <> '9'    --TK01  
     
   IF @@ERROR <> 0  
   BEGIN  
      SET @n_continue = 3  
      SET @n_err = 68020  
      SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
                       + ': Update Priority in TaskDetail failed. (isp_GTM_WSTaskAssignment)'  
      GOTO QUIT  
   END  
  
   /******************************************************************/  
   /* Assign Pallet                                                  */  
   /******************************************************************/  
   --WHILE EXISTS ( --Exist when any station with pallet Count less than @n_MaxPltPerWS where Status in 0,1,2,6,7  
   --               --Declare @n_MaxPltPerWS INT = 8  
   --               --SELECT 1 FROM Codelkup CLK WITH (NOLOCK)  
   --               --LEFT OUTER JOIN GTMTask GT WITH (NOLOCK)   
   --               --ON GT.WorkStation = CLK.UDF01   
   --               --AND GT.Status IN ('0','1','2','6','7')  
   --               --WHERE CLK.ListName = 'ASRSGTMWS'      --               --AND CLK.UDF03 = '1'   
   --               --GROUP BY CLK.UDF01  
   --               --HAVING COUNT(GT.PalletID) < @n_MaxPltPerWS  
  
   --               SELECT 1 FROM V_GTM_PalletCount  
   --               --WHERE WorkStation <> ''  
   --               GROUP BY WorkStation  
   --               HAVING SUM(PendingCOut + PltOTW2Loop + PltInLoop + PltInWS) < @n_MaxPltPerWS  
  
   --)  
   --BEGIN  
  
   --   SET @c_WS      = ''  
   --   SET @n_SeqNo   = 0  
        
   --   --Get SeqNo of highest priority Task/Order. Task with OrderKey will share same SeqNo.  
   --   SELECT TOP 1 @n_SeqNo = ISNULL(SeqNo,0), @c_WS = ISNULL(Workstation,'')  
   --   FROM GTMTask WITH (NOLOCK)  
   --   WHERE Status = 'Q'  
   --   AND WorkStation NOT IN (  
   --      --Excluding workstation which already hit MaxPltPerWS  
   --      SELECT WorkStation FROM V_GTM_PalletCount WITH (NOLOCK)  
   --      WHERE WorkStation <> ''  
   --      GROUP BY WorkStation  
   --      HAVING SUM(PendingCOut + PltOTW2Loop + PltInLoop + PltInWS) >= @n_MaxPltPerWS  
   --   )  
   --   ORDER BY SeqNo, Workstation ASC  
  
   --   --Break out of while loop when no more pending task in GTMTask table  
   --   IF @n_SeqNo = 0     
   --   BEGIN  
   --      BREAK  
   --   END  
   --   ELSE  
   --   BEGIN  
  
   --      --If no preassigned WorkStation, assign to workstation with lowest pallet count.  
   --      IF @c_WS = ''  
   --      BEGIN  
   --         --Get workstation with Lowest pallet count  
   --         ----Declare @c_WS NVARCHAR(1) = '', @n_MaxPltPerWS INT = 6  
   --         SELECT TOP 1 @c_WS = ISNULL(RTRIM(CLK.UDF01),'')  
   --         FROM Codelkup CLK WITH (NOLOCK)  
   --         LEFT OUTER JOIN GTMTask GT WITH (NOLOCK)   
   --         ON GT.WorkStation = CLK.UDF01 AND GT.Status IN ('0','1','2','6','7')  
   --         WHERE CLK.ListName = 'ASRSGTMWS'   
   --         AND CLK.UDF03 = '1'   
   --         GROUP BY CLK.UDF01  
   --         HAVING COUNT(GT.TaskDetailKey) < @n_MaxPltPerWS  
   --         ORDER BY COUNT(GT.TaskDetailKey) ASC, ISNULL(RTRIM(CLK.UDF01),'') ASC  
        
   --      END  
        
        
   /******************************************************************/  
   /* Assign Pallet                                                  */  
   /******************************************************************/  
   --Get SeqNo of highest priority Task/Order. Task with OrderKey will share same SeqNo.  
   ----Declare @c_WS NVARCHAR(1) = '', @n_MaxPltPerWS INT = 6  
   DECLARE C_QRYSEQNO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT ISNULL(SeqNo,0), ISNULL(Workstation,'')  
   FROM GTMTask WITH (NOLOCK)  
   WHERE Status = 'Q'  
   AND WorkStation NOT IN (  
      --Excluding workstation which already hit MaxPltPerWS  
      SELECT WorkStation FROM V_GTM_PalletCount WITH (NOLOCK)  
      WHERE WorkStation <> ''  
      GROUP BY WorkStation  
      HAVING SUM(PendingCOut + PltOTW2Loop + PltInLoop + PltInWS) >= @n_MaxPltPerWS  
   )  
      ORDER BY ISNULL(SeqNo,0), ISNULL(Workstation,'') ASC  
  
   OPEN C_QRYSEQNO    
   FETCH NEXT FROM C_QRYSEQNO INTO @n_SeqNo, @c_WS  
     
   WHILE (@@FETCH_STATUS <> -1)  
   BEGIN  
     
      --Break out of while loop when no more pending task in GTMTask table  
      IF @n_SeqNo = 0     
      BEGIN  
         BREAK  
      END  
      ELSE  
      BEGIN  
  
         ----If no preassigned WorkStation, assign to workstation with lowest pallet count.  
         IF @c_WS = ''  
         BEGIN  
            --Get workstation with Lowest pallet count  
            ----Declare @c_WS NVARCHAR(1) = '', @n_MaxPltPerWS INT = 6  
            --SELECT TOP 1 @c_WS = ISNULL(RTRIM(CLK.UDF01),'')  
            --FROM Codelkup CLK WITH (NOLOCK)  
            --LEFT OUTER JOIN GTMTask GT WITH (NOLOCK)   
            --ON GT.WorkStation = CLK.UDF01 AND GT.Status IN ('0','1','2','6','7')  
            --WHERE CLK.ListName = 'ASRSGTMWS'   
            --AND CLK.UDF03 = '1'   
            --GROUP BY CLK.UDF01  
            --HAVING COUNT(GT.TaskDetailKey) < @n_MaxPltPerWS  
            --ORDER BY COUNT(GT.TaskDetailKey) ASC, ISNULL(RTRIM(CLK.UDF01),'') ASC  
  
  
            SELECT TOP 1 @c_WS = ISNULL(RTRIM(CLK.UDF01),'')  
            FROM Codelkup CLK WITH (NOLOCK)  
            LEFT OUTER JOIN GTMloop GT WITH (NOLOCK)      
            ON GT.WorkStation = CLK.UDF01 --AND GT.Status IN ('Q','0','1','2','6','7')  
            WHERE CLK.ListName = 'ASRSGTMWS'   
            AND CLK.UDF03 = '1'   
            GROUP BY CLK.UDF05, CLK.UDF01  
            HAVING COUNT(GT.PalletID) < @n_MaxPltPerWS  
            ORDER BY COUNT(GT.PalletID) ASC, ISNULL(RTRIM(CLK.UDF05),'') ASC  
  
  
         END  
  
         IF @c_WS <> ''  
         BEGIN  
            --Assign WS number to the tasks.  
            UPDATE GTMTask WITH (ROWLOCK)  
            SET WorkStation = @c_WS , Status = '0'  
            WHERE SeqNo = @n_SeqNo  
            AND STATUS = 'Q'  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @n_continue = 3  
               SET @n_err = 68031  
               SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
                                 + ': Update WorkStation in GTMTask failed. (isp_GTM_WSTaskAssignment)'  
               GOTO QUIT  
            END  
  
            INSERT INTO GTMLog (PalletId, TaskDetailKey, MsgType, FromLoc, ToLoc, LogDate, EditBy, ErrCode, ErrMsg)  
            VALUES ('', '', 'isp_GTM_WSTaskAssignment', CONVERT(CHAR(5),ISNULL(@n_SeqNo,0)), @c_WS, getdate(), system_User, @n_Err, 'WSAssign --> SET WS = ' + @c_WS + ' WHERE SeqNo =' + CONVERT(CHAR(5),ISNULL(@n_SeqNo,0)) + ' AND Status = 0')  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @n_continue = 3  
               SET @n_err = 68032  
               SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
                                 + ': INSERT into GTMLog failed. (isp_GTM_WSTaskAssignment)'  
            END  
         END  
      END  
        
      FETCH NEXT FROM C_QRYSEQNO INTO @n_SeqNo, @c_WS  
  
   END  
   CLOSE C_QRYSEQNO  
   DEALLOCATE C_QRYSEQNO  
  
           
   --/******************************************************************/  
   --/* Assign Pallet                       */  
   --/******************************************************************/  
   ----Get SeqNo of highest priority Task/Order. Task with OrderKey will share same SeqNo.  
   ------Declare @c_WS NVARCHAR(1) = '', @n_SeqNo INT = 0, @n_MaxPltPerWS INT = 6  
   --DECLARE C_QRYSEQNO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   --SELECT ISNULL(SeqNo,0), ISNULL(Workstation,'')  
   --FROM GTMTask WITH (NOLOCK)  
   --WHERE Status = 'Q'  
   ----AND WorkStation NOT IN (  
   ----   --Excluding workstation which already hit MaxPltPerWS  
   ----   SELECT WorkStation FROM V_GTM_PalletCount WITH (NOLOCK)  
   ----   WHERE WorkStation <> ''  
   ----   GROUP BY WorkStation  
   ----   HAVING SUM(PendingCOut + PltOTW2Loop + PltInLoop + PltInWS) >= 6 --@n_MaxPltPerWS  
   ----)  
   --ORDER BY SeqNo, Workstation ASC  
  
   --OPEN C_QRYSEQNO    
   --FETCH NEXT FROM C_QRYSEQNO INTO @n_SeqNo, @c_WS  
     
   --WHILE (@@FETCH_STATUS <> -1)  
   --BEGIN  
  
   --   --Break out of while loop when no more pending task in GTMTask table  
   --   IF @n_SeqNo = 0  
   --   BEGIN  
   --      BREAK  
   --   END  
   --   ELSE  
   --   BEGIN  
  
   --      ----If no preassigned WorkStation, assign to workstation with lowest pallet count.  
   --      IF @c_WS = ''  
   --      BEGIN  
   --         --Get workstation with Lowest pallet count  
   --         ------Declare @c_WS NVARCHAR(1) = '', @n_MaxPltPerWS INT = 6  
   --         --SELECT * --TOP 1 @c_WS = ISNULL(RTRIM(CLK.UDF01),'')  
   --         --FROM Codelkup CLK WITH (NOLOCK)  
   --         --LEFT OUTER JOIN GTMTask GT WITH (NOLOCK)   
   --         --ON GT.WorkStation = CLK.UDF01 AND GT.Status IN ('0','1','2','6','7')  
   --         --WHERE CLK.ListName = 'ASRSGTMWS'   
   --         --AND CLK.UDF03 = '1'   
   --         --GROUP BY CLK.UDF01  
   --         --HAVING COUNT(GT.PalletID) < @n_MaxPltPerWS  
   --         --ORDER BY COUNT(GT.PalletID) ASC, ISNULL(RTRIM(CLK.UDF01),'') ASC  
  
   --         --Get workstation with Lowest pallet count  
   --         ----Declare @c_WS NVARCHAR(1) = '', @n_MaxPltPerWS INT = 6  
   --         SELECT TOP 1 @c_WS = ISNULL(RTRIM(WorkStation),'')  
   --         FROM V_GTM_PalletCount WITH (NOLOCK)  
   --         WHERE WorkStation <> ''  
   --         GROUP BY WorkStation  
   --         HAVING SUM(PendingCOut + PltOTW2Loop + PltInLoop + PltInWS) < @n_MaxPltPerWS  
  
  
   --         --Select * from V_GTM_PalletCount  
   --      END  
  
   --      ----If still cant get any available WorkStation; Break  
   --      IF @c_WS = ''  
   --      BEGIN  
   --         BREAK  
   --      END  
   --      ELSE  
   --      BEGIN  
   --         --Assign WS number to the tasks.  
   --         UPDATE GTMTask WITH (ROWLOCK)  
   --         SET WorkStation = @c_WS , Status = '0'  
   --         WHERE SeqNo = @n_SeqNo  
   --         AND STATUS = 'Q'  
  
   --         IF @@ERROR <> 0  
   --         BEGIN  
   --            SET @n_continue = 3  
   --            SET @n_err = 68020  
   --            SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
   --                              + ': Update WorkStation in GTMTask failed. (isp_GTM_WSTaskAssignment)'  
   --            GOTO QUIT  
   --         END  
   --      END  
  
   --   END  
        
   --   FETCH NEXT FROM C_QRYSEQNO INTO @n_SeqNo, @c_WS  
  
   --END  
   --CLOSE C_QRYSEQNO  
   --DEALLOCATE C_QRYSEQNO  
  
   QUIT:  
  
   IF CURSOR_STATUS('GLOBAL' , 'C_RESETSEQNO ') in (0 , 1)  
   BEGIN  
      CLOSE C_RESETSEQNO   
      DEALLOCATE C_RESETSEQNO   
   END  
     
   IF CURSOR_STATUS('GLOBAL' , 'C_UPDSEQNO ') in (0 , 1)  
   BEGIN  
      CLOSE C_UPDSEQNO   
      DEALLOCATE C_UPDSEQNO   
   END  
  
   IF CURSOR_STATUS('GLOBAL' , 'C_QRYSEQNO ') in (0 , 1)  
   BEGIN  
      CLOSE C_QRYSEQNO   
      DEALLOCATE C_QRYSEQNO   
   END  
     
   IF CURSOR_STATUS('GLOBAL' , 'C_UPDWS ') in (0 , 1)  
   BEGIN  
      CLOSE C_UPDWS   
      DEALLOCATE C_UPDWS   
   END  
  
   IF CURSOR_STATUS('GLOBAL' , 'C_UPDTaskDetail') in (0 , 1)  
   BEGIN  
      CLOSE C_UPDTaskDetail   
      DEALLOCATE C_UPDTaskDetail   
   END  
  
END  

GO