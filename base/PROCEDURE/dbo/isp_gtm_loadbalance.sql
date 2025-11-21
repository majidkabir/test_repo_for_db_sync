SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store Procedure:  isp_GTM_LoadBalance                                */  
/* Creation Date: 16 Aug 2015                                           */  
/* Copyright: LFL                                                       */  
/* Written by: TKLIM                                                    */  
/*                                                                      */  
/* Purpose: Query, Calculate and Reshuffle Task between Workstations    */  
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
/* 06-Jan-2016  TKLIM     1.0   DEADLOCK prevention (TK01)              */  
/* 19-Jul-2016  Barnett         Revamp Logic (BL01)                     */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_GTM_LoadBalance]   
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
          
   DECLARE @n_SeqNo           INT  
         , @c_OrderKey        NVARCHAR(10)  
         , @c_TaskDetailKey   NVARCHAR(10)  
         , @c_Priority        NVARCHAR(1)  
   , @c_Status          NVARCHAR(10)  
   , @c_PalletID        NVARCHAR(18)  
  
   /*********************************************/  
   /* Variables Defaults (Start)             */  
   /*********************************************/  
   SET @n_continue         = 1  
  
   SET @n_ActiveWS         = 0  
   SET @n_MaxPltInGTMArea  = 0  
   SET @n_MaxPltInWS       = 0  
   SET @n_MaxPltPerWS      = 0  
   SET @c_WS               = ''  
  
   SET @n_SeqNo            = 0  
   SET @c_OrderKey         = ''  
   SET @c_TaskDetailKey    = ''  
   SET @c_Priority         = '5'  
   SET @c_Status     = ''  
  
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
  
   --BEGIN TRAN   -- (TK01)  
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
   /* Order Picking task shall share same SeqNo.                           */  
   /* Update ASRSPK task SeqNo to Min(SeqNo) Group By OrderKey             */  
   /************************************************************************/  
   --Declare @c_OrderKey NVARCHAR(10) , @n_SeqNo INT  
   --DECLARE C_UPDSEQNO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    -- (BL01 - No need handle group by order anymore)  
   --SELECT OrderKey, MIN(SeqNo)   
   --FROM GTMTask WITH (NOLOCK)  
   --WHERE TaskType = 'ASRSPK' AND ISNULL(RTRIM(OrderKey),'') <> ''  
   --GROUP BY OrderKey  
   --HAVING MIN(SeqNo) <> MAX(SeqNo)  
  
   --OPEN C_UPDSEQNO    
   --FETCH NEXT FROM C_UPDSEQNO INTO @c_OrderKey, @n_SeqNo  
        
   --WHILE (@@FETCH_STATUS <> -1)       
   --BEGIN  
   --   IF EXISTS ( SELECT 1 FROM GTMTask WITH (NOLOCK)  
   --               WHERE OrderKey = @c_OrderKey  
   --               AND SeqNo <> @n_SeqNo)  
   --   BEGIN  
   --      UPDATE GTMTask WITH (ROWLOCK)  
   --      SET SeqNo = @n_SeqNo  
   --      WHERE SeqNo <> @n_SeqNo  
   --      AND OrderKey = @c_OrderKey  
  
   --      IF @@ERROR <> 0  
   --      BEGIN  
   --         SET @n_continue = 3  
   --         SET @n_err = 68012  
   --         SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
   --                          + ': Update SeqNo for Order in GTMTask failed. (isp_GTM_WSTaskAssignment)'  
   --         GOTO QUIT  
   --      END  
   --   END  
  
   --   FETCH NEXT FROM C_UPDSEQNO INTO @c_OrderKey, @n_SeqNo  
  
   --END  
   --CLOSE C_UPDSEQNO  
   --DEALLOCATE C_UPDSEQNO  
  
   /******************************************************************/  
   /* RESET GTMTask.WorkStation = '' to indicate pending reshuffle   */  
   /******************************************************************/  
   UPDATE GTMTask SET WorkStation = ''  
   FROM GTMTask GT WITH (ROWLOCK)  
   INNER JOIN TaskDetail TD WITH (NOLOCK)  
   ON GT.TaskDetailKey = TD.TaskDetailKey   
   AND TD.FinalLoc IN ('GTMWS','')  
   WHERE GT.Status IN ('0','1','2')  
   AND GT.Orderkey NOT IN (  
      SELECT DISTINCT OrderKey FROM GTMTask WITH (NOLOCK)  
      WHERE Status IN ('6','7')   
      AND TaskType = 'ASRSPK'  
   )  
  
   IF @@ERROR <> 0  
   BEGIN  
      SET @n_continue = 3  
      SET @n_err = 68010  
      SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
                       + ': Update RefTaskKey in TaskDetail failed. (isp_GTM_LoadBalance)'  
      GOTO QUIT  
   END  
  
   /******************************************************************/  
   /* ReAssign WorkStation based on Priority SeqNo                   */  
   /******************************************************************/  
   --Get SeqNo of highest priority Task/Order. Task with OrderKey will share same SeqNo.  
   DECLARE C_QRYSEQNO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
     
   --SELECT DISTINCT ISNULL(SeqNo,0), ISNULL(Workstation,''), Status  
   --FROM GTMTask WITH (NOLOCK)  
   --WHERE (Status IN ('0','1','2') AND WorkStation = '')  
   --OR (Status = 'Q' AND WorkStation <> '')  
   --ORDER BY Status DESC, ISNULL(SeqNo,0) ASC  
     
  
   --Revamp Logic (BL01)  
   --Retrieve all the pallet already call out or already in GTMLoop  
   SELECT DISTINCT ISNULL(GT.SeqNo,0), ISNULL(GL.Workstation,''), GL.Status, GL.PalletID  
   FROM GTMLoop GL WITH (NOLOCK)  
   JOIN GTMTASK GT WITH (NOLOCK) ON GT.PalletID = GL.PalletId  
   WHERE (GL.Status IN ('1','2') AND GL.WorkStation = '' and GT.TaskType NOT IN ( 'ASRSQC', 'ASRSCC'))  
   ORDER BY GL.Status DESC, ISNULL(GT.SeqNo,0) ASC  
  
  
   OPEN C_QRYSEQNO    
   FETCH NEXT FROM C_QRYSEQNO INTO @n_SeqNo, @c_WS, @c_Status, @c_PalletID  
     
   WHILE (@@FETCH_STATUS <> -1)  
   BEGIN  
  
      IF @c_WS = ''  
      BEGIN  
         --Get workstation with Lowest pallet count  
         ----Declare @c_WS NVARCHAR(1) = '', @n_MaxPltPerWS INT = 6  
  
         --SELECT TOP 1 @c_WS = ISNULL(RTRIM(CLK.UDF01),'')  
         --FROM Codelkup CLK WITH (NOLOCK)  
         --LEFT OUTER JOIN GTMTask GT WITH (NOLOCK)      
         --ON GT.WorkStation = CLK.UDF01 AND GT.Status IN ('Q','0','1','2','6','7')  
         --WHERE CLK.ListName = 'ASRSGTMWS'   
         --AND CLK.UDF03 = '1'   
         --GROUP BY CLK.UDF01  
         --HAVING COUNT(GT.PalletID) < @n_MaxPltPerWS  
         --ORDER BY COUNT(GT.PalletID) ASC, ISNULL(RTRIM(CLK.UDF01),'') ASC  
  
     --Get Workstation from GTMLoop record with lowest pallet count (BL01)  
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
  
      ----IF pallet still cant get available slot without exceeding @n_MaxPltPerWS count.  
      ----Assign to Workstation with lowest count WITHOUT checking the @n_MaxPltPerWS  
      --IF @c_WS = ''  
      --BEGIN  
      --   --Get workstation with Lowest pallet count WITHOUT checking the @n_MaxPltPerWS  
      --   ----Declare @c_WS NVARCHAR(1) = '', @n_MaxPltPerWS INT = 6  
      --   SELECT TOP 1 @c_WS = ISNULL(RTRIM(CLK.UDF01),'')  
      --   FROM Codelkup CLK WITH (NOLOCK)  
      --   LEFT OUTER JOIN GTMTask GT WITH (NOLOCK)   
      --   ON GT.WorkStation = CLK.UDF01 AND GT.Status IN ('0','1','2','6','7')  
      --   WHERE CLK.ListName = 'ASRSGTMWS'   
      --   AND CLK.UDF03 = '1'   
      --   GROUP BY CLK.UDF01  
      --   ORDER BY COUNT(GT.PalletID) ASC, ISNULL(RTRIM(CLK.UDF01),'') ASC  
      --END  
  
      ----Get workstation with Lowest pallet count  
      ----If the Workstation contain any other higher priority task with Status 'Q' pending call out, assign to next station  
      ------Declare @c_WS NVARCHAR(1) = '', @n_MaxPltPerWS INT = 6  
      --SELECT TOP 1 @c_WS = ISNULL(RTRIM(CLK.UDF01),'')  
      --FROM Codelkup CLK WITH (NOLOCK)  
      --LEFT OUTER JOIN GTMTask GT WITH (NOLOCK)   
      --ON GT.WorkStation = CLK.UDF01 AND GT.Status IN ('0','1','2','6','7')  
      --LEFT OUTER JOIN (  
      --      SELECT WorkStation, MIN(SeqNo) [MinSeqNo] FROM GTMTask (NOLOCK)   
      --      WHERE Status = 'Q' AND Priority < 5  
      --      GROUP BY WorkStation  
      --) PT ON PT.WorkStation = GT.WorkStation  
      --WHERE CLK.ListName = 'ASRSGTMWS'   
      --AND CLK.UDF03 = '1'   
      --AND PT.MinSeqNo < @n_SeqNo  
      --GROUP BY CLK.UDF01  
      --HAVING COUNT(GT.PalletID) < @n_MaxPltPerWS  
      --ORDER BY COUNT(GT.PalletID) ASC, ISNULL(RTRIM(CLK.UDF01),'') ASC  
        
      ----IF pallet still cant get available slot without exceeding @n_MaxPltPerWS count.  
      ----Assign to Workstation with lowest count WITHOUT checking the @n_MaxPltPerWS  
      --IF @c_WS = ''  
      --BEGIN  
      --   --Get workstation with Lowest pallet count WITHOUT checking the @n_MaxPltPerWS  
      --   ----Declare @c_WS NVARCHAR(1) = '', @n_MaxPltPerWS INT = 6  
      --   SELECT TOP 1 @c_WS = ISNULL(RTRIM(CLK.UDF01),'')  
      --   FROM Codelkup CLK WITH (NOLOCK)  
      --   LEFT OUTER JOIN GTMTask GT WITH (NOLOCK)   
      --   ON GT.WorkStation = CLK.UDF01 AND GT.Status IN ('0','1','2','6','7')  
      --   LEFT OUTER JOIN (  
      --         SELECT WorkStation, MIN(SeqNo) [MinSeqNo] FROM GTMTask (NOLOCK)   
      --         WHERE Status = 'Q' AND Priority < 5 AND   
      --         GROUP BY WorkStation  
      --   ) PT ON PT.WorkStation = GT.WorkStation  
      --   WHERE CLK.ListName = 'ASRSGTMWS'   
      --   AND CLK.UDF03 = '1'   
      --   AND PT.MinSeqNo < @n_SeqNo  
      --   GROUP BY CLK.UDF01  
      --   ORDER BY COUNT(GT.PalletID) ASC, ISNULL(RTRIM(CLK.UDF01),'') ASC  
      --END  
     
      IF @c_WS <> ''  
      BEGIN  
  
      /*  
         IF EXISTS ( SELECT 1 FROM GTMTask WITH (NOLOCK)  
                     WHERE SeqNo = @n_SeqNo  
                     AND WorkStation <> @c_WS  
                     AND Status NOT IN ('6','7')   -- (TK01)  
                  )  
         BEGIN  
  
            --Assign WS number to the tasks with that SeqNo  
            UPDATE GTMTask WITH (ROWLOCK)  
            SET WorkStation = @c_WS  
            WHERE SeqNo = @n_SeqNo  
            AND Status NOT IN ('6','7')   -- (TK01)  
            --AND Status IN ('0','1','2')  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @n_continue = 3  
               SET @n_err = 68020  
               SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
                                 + ': Update WorkStation in GTMTask failed. (isp_GTM_LoadBalance)'  
               GOTO QUIT  
            END  
         END  
   */  
        --Assign WS number to the tasks with that SeqNo  
            UPDATE GTMTask WITH (ROWLOCK)  
            SET WorkStation = @c_WS  
            WHERE SeqNo = @n_SeqNo and PalletID = @c_PalletID  
            AND Status NOT IN ('6','7')   -- (TK01)  
            --AND Status IN ('0','1','2')  
  
   IF @@ERROR <> 0  
   BEGIN  
    SET @n_continue = 3  
    SET @n_err = 68020  
    SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))  
         + ': Update WorkStation in GTMTask failed. (isp_GTM_LoadBalance)'  
    GOTO QUIT  
   END      
     
      END  
     
      FETCH NEXT FROM C_QRYSEQNO INTO @n_SeqNo, @c_WS, @c_Status, @c_PalletID  
  
   END  
   CLOSE C_QRYSEQNO  
   DEALLOCATE C_QRYSEQNO  
  
   QUIT:  
     
   IF @n_continue = 3  
   BEGIN  
      --ROLLBACK TRAN   -- (TK01)  
  
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_GTM_LoadBalance'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
  
   END  
   ---- (TK01) - Start  
   --ELSE  
   --BEGIN  
   --   COMMIT TRAN  
   --END  
   ---- (TK01) - End  
  
   IF CURSOR_STATUS('GLOBAL' , 'C_QRYSEQNO ') in (0 , 1)  
   BEGIN  
      CLOSE C_QRYSEQNO   
      DEALLOCATE C_QRYSEQNO   
   END  
     
  
END  
  
  
--EXECUTE isp_GTM_LoadBalance @b_Success = '1', @n_err = 0, @c_ErrMsg = '' , @b_debug= '0'   

GO