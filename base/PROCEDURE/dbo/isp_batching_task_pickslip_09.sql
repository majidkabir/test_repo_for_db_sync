SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/********************************************************************************/  
/* Store Procedure:  isp_batching_task_pickslip_09                              */  
/* Creation Date:  22-JUL-2022                                                  */  
/* Copyright: Maersk                                                            */  
/* Written by:CSCHONG                                                           */  
/*                                                                              */  
/* Purpose: WMS-22850-MYSûADIDASûModify Task Pickslip Report                    */  
/*          copy from isp_batching_task_pickslip_03                             */  
/*                                                                              */  
/* Input Parameters:                                                            */  
/*                                                                              */  
/* Output Parameters:  None                                                     */  
/*                                                                              */  
/* Return Status:  None                                                         */  
/*                                                                              */  
/* Usage:                                                                       */  
/*                                                                              */  
/* Local Variables:                                                             */  
/*                                                                              */  
/* Called By:                                                                   */  
/*                                                                              */  
/* PVCS Version: 1.6                                                            */  
/*                                                                              */  
/* Version: 5.4                                                                 */  
/*                                                                              */  
/* Data Modifications:                                                          */  
/*                                                                              */  
/* Updates:                                                                     */  
/* Date        Author   Ver.  Purposes                                          */  
/* 22/07/2023  CSCHONG  1.0   Devops Scripts Combine                            */
/********************************************************************************/  
  
CREATE   PROC [dbo].[isp_batching_task_pickslip_09] (  
            @c_Loadkey NVARCHAR(10)  
           ,@c_OrderCount NVARCHAR(10) = '9999'  
           ,@c_TaskBatchNo NVARCHAR(10) = ''  
           ,@c_Pickzone NVARCHAR(4000) = ''  --INC0152000  
           ,@c_Mode NVARCHAR(10) = ''  -- 1=Multi-S 4=Multi-M 5=BIG 9=Single  
           ,@c_ReportType NVARCHAR(10) = '0' -- 0=Main   1=Single & BIG   2=Multi S & M   3=Sub report of Multi S & M(pick detail)  4=Sub report of Multi S & M(zone summary)   
           ,@c_ReGen NVARCHAR(10) = 'N' --Regnerate flag Y/N           -- 5=Sub report of Multi S & M(Conso Pick when MultiConsoTaskPick=1)                                               
           ,@c_updatepick  NCHAR(1) = 'N'   
           ,@c_printflag   NCHAR(50) = ''  
 )  
 AS  
 BEGIN  
    SET NOCOUNT ON   
    SET QUOTED_IDENTIFIER OFF   
    SET CONCAT_NULL_YIELDS_NULL OFF  
      
    DECLARE @b_Success             INT             
           ,@n_Err                 INT             
           ,@c_ErrMsg              NVARCHAR(255)   
           ,@n_OrderCount          INT  
           ,@c_ZoneList            NVARCHAR(4000)  --INC0152000   
           ,@n_StartTCnt           INT  
           ,@n_Continue            INT  
           ,@c_Orderkey            NVARCHAR(10)  
           ,@c_Loc                 NVARCHAR(10)  
           ,@c_Sku                 NVARCHAR(20)  
           ,@n_Qty                 INT  
           ,@c_Storerkey           NVARCHAR(15)  
           ,@c_Facility            NVARCHAR(5)  
           ,@c_MultiConsoTaskPick  NVARCHAR(30)  
           ,@c_CallSource          NVARCHAR(10)  
           ,@n_StyleMaxLen         INT           
           ,@c_PrintRemark         NVARCHAR(50)  
           ,@c_BuildOptDescr       NVARCHAR(250)  
           ,@c_GetTaskBatchNo      NVARCHAR(10)  
            
    SELECT @b_Success = 1, @n_Err = 0, @c_Errmsg = '', @c_ZoneList = '', @n_StartTCnt = @@TRANCOUNT, @n_Continue = 1    
  
    SELECT @n_OrderCount = CONVERT(INT, @c_OrderCount)  
      
    IF ISNULL(@c_PickZone,'') = ''  
       SET @c_PickZone = ''  
  
    IF ISNULL(@c_TaskBatchNo,'') = ''  
       SET @c_TaskBatchNo = ''  
  
    IF @c_Mode NOT IN('1','4','5','9')  
    BEGIN   
       SELECT @n_Continue = 3    
       SELECT @n_Err = 63200    
       SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Invalid Mode. The value must be 1,4,5,9 (isp_batching_task_pickslip_09)'   
       GOTO Quit  
    END  
         
    IF @c_PickZone = 'ALL'  
    BEGIN  
   --ian 1.0 start
      SELECT @c_ZoneList = STUFF((SELECT ',' + RTRIM(Loc.PickZone)    
                            FROM ORDERS O (NOLOCK)
                            JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey     
                            JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
                            WHERE O.Loadkey = @c_Loadkey
                            GROUP BY LOC.PickZone 
                            ORDER BY LOC.PickZone FOR XML PATH('')),1,1,'' ) + ','  
   --ian 1.0 end
        
      IF ISNULL(@c_ZoneList,'') <> ''  
      BEGIN  
          SET @c_ZoneList = LEFT(@c_ZoneList, LEN(RTRIM(@c_ZoneList)) - 1)  
          SET @c_PickZone = @c_ZoneList  
      END  
    END         

   --(CLVN01) START--
   DECLARE @PICKZONE TABLE (PICKZONE NVARCHAR(30))
   IF @c_PickZone = ''
   BEGIN
      INSERT INTO @PICKZONE (PICKZONE) VALUES ('')
   END
   ELSE
   BEGIN
      INSERT INTO @PICKZONE
      SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_PickZone)
   END
   --(CLVN01) END--
  
    IF @c_ReportType IN ('2','3','5')  
    BEGIN  
       SELECT TOP 1 @c_Storerkey = Storerkey,  
                    @c_Facility = Facility  
       FROM ORDERS (NOLOCK)   
       WHERE Loadkey = @c_Loadkey         
               
       SET @c_MultiConsoTaskPick = ''  
       Execute nspGetRight   
       @c_facility,    
       @c_StorerKey,                
       '', --@c_Sku                      
       'MultiConsoTaskPick', -- Configkey  
       @b_success            OUTPUT,  
       @c_MultiConsoTaskPick OUTPUT,  
       @n_err                OUTPUT,  
       @c_errmsg             OUTPUT                
    END       
  
   SET  @c_PrintRemark = ''  
   SET  @c_BuildOptDescr  = ''  
     

    SELECT top 1  @c_BuildOptDescr = c.buildparmkey + ' - ' + c.DESCRIPTION 
    FROM BuildwaveDetailLog a WITH (NOLOCK)
    JOIN BuildwaveLog b WITH (NOLOCK) ON a.BatchNo = b.BatchNo
    JOIN buildparm c WITH (NOLOCK) ON c.buildparmkey = b.BuildParmkey 
    JOIN orders d  WITH (NOLOCK) ON d.userdefine09 = a.wavekey
    WHERE d.loadkey = @c_LoadKey
      
     
      
    IF @c_ReportType = '0'  
    BEGIN  
        
       IF @c_ReGen = 'Y'  
          SET @c_CallSource = 'RPTREGEN'  
       ELSE  
          SET @c_CallSource = 'RPT'     
        
      SET  @c_GetTaskBatchNo = ''  
      SELECT @c_GetTaskBatchNo = ISNULL(PT.TaskBatchNo,'')  
      FROM LOADPLANDETAIL LP (NOLOCK)  
               JOIN PICKDETAIL PD (NOLOCK) ON LP.orderkey = PD.OrderKey  
               JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku  
               JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey   
               JOIN LOC L (NOLOCK) ON PD.Loc = L.Loc  
               JOIN PACKTASK PT (NOLOCK) ON PD.Orderkey = PT.Orderkey  
               WHERE LP.Loadkey = @c_Loadkey  
  
   --IF EXISTS ( SELECT 1   
   --            FROM LOADPLANDETAIL LP (NOLOCK)  
   --            JOIN PICKDETAIL PD (NOLOCK) ON LP.orderkey = PD.OrderKey  
   --            JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku  
   --            JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey   
   --            JOIN LOC L (NOLOCK) ON PD.Loc = L.Loc  
   --            JOIN PACKTASK PT (NOLOCK) ON PD.Orderkey = PT.Orderkey  
   --            WHERE LP.Loadkey = @c_Loadkey  
   --            AND PT.TaskBatchNo = ''  
   --            AND L.Pickzone IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_PickZone))   
   --            AND RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) = @c_Mode  
   --            AND 1 = CASE WHEN (@c_ReportType = '3' AND @c_MultiConsoTaskPick = '1') OR (@c_ReportType = '5' AND @c_MultiConsoTaskPick <> '1') THEN 2 ELSE 1 END)  
    IF ISNULL(@c_GetTaskBatchNo,'') <> ''  
    BEGIN  
       SET @c_PrintRemark = 'REPRINT'  
    END  
    ELSE  
    BEGIN  
      SET @c_PrintRemark = 'ORIGINAL'  
    END  
  
       WHILE @@TRANCOUNT > 0  
         COMMIT  
        
       BEGIN TRAN    
  
      EXEC ispOrderBatching  
          @c_LoadKey     = @c_LoadKey  
         ,@n_OrderCount  = @n_OrderCount    
         ,@c_PickZones   = @c_PickZone  
         ,@c_Mode        = @c_Mode  
         ,@b_Success     = @b_Success   OUTPUT    
         ,@n_Err         = @n_Err       OUTPUT    
         ,@c_ErrMsg      = @c_ErrMsg    OUTPUT  
         ,@c_CallSource  = @c_CallSource  
         ,@c_updatepick  = @c_updatepick  
             
       IF @b_Success = 0  
       BEGIN  
          ROLLBACK  
                     
          SELECT @n_Continue = 3   
          GOTO Quit  
       END    
         
       WHILE @@TRANCOUNT > 0  
          COMMIT  
    END                
  
    SELECT PT.TaskBatchNo,   
           PD.Orderkey,  
           PD.Notes,   
           LP.Loadkey,   
           SUM(PD.Qty) AS Qty,  
           L.PickZone,  
           CASE WHEN ISNULL(CL.Long,'') <> '' THEN  
                CL.Long  
           ELSE RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) END AS ModeDesc,  
           RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) AS Mode,  
           PD.Loc,  
           L.LogicalLocation,  
           PD.Sku,  
           SKU.Descr,  
           PACK.Casecnt,      
           CASE WHEN ISNULL(CL2.Code,'') <> '' THEN 'Y' ELSE 'N' END AS ShowStyleSize,     
           ISNULL(SKU.Style,'') AS Style,     
           ISNULL(SKU.Size,'') AS Size    
           --,'' AS Altsku    --,RIGHT(RTRIM(SKU.AltSKU),4) AS Altsku          
         , AltSku = CASE WHEN @c_ReportType = '1' THEN SKU.AltSKU ELSE '' END     
         , CASE WHEN ISNULL(CL3.Code,'') <> '' THEN 'Y' ELSE 'N' END AS Showloadkeybarcode     
         , ISNULL(CL4.Short,'N') AS ShowCurrentDateTime     
         , @c_PrintRemark as PrintRemarks  
         , @c_BuildOptDescr as BuildOptDescr  
         , stylesize = CASE WHEN @c_ReportType in ('1','5') THEN SKU.style + '-' + SKU.size ELSE '' END
         , CASE WHEN ISNULL(CL5.Code,'') <> '' THEN 'Y' ELSE 'N' END AS HideAltsku   
    INTO #TMP_TASK  
    FROM LOADPLANDETAIL LP (NOLOCK)  
    JOIN PICKDETAIL PD (NOLOCK) ON LP.orderkey = PD.OrderKey  
    JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku  
    JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey   
    JOIN LOC L (NOLOCK) ON PD.Loc = L.Loc  
    JOIN PACKTASK PT (NOLOCK) ON PD.Orderkey = PT.Orderkey  
    LEFT JOIN CODELKUP CL ON RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) = CL.Code AND CL.Listname = 'BATCHMODE'   
    LEFT JOIN Codelkup CL2 (NOLOCK) ON (PD.Storerkey = CL2.Storerkey AND CL2.Code = 'SHOWSTYLESIZE'   
                                              AND CL2.Listname = 'REPORTCFG' AND CL2.Long = 'isp_batching_task_pickslip_09' AND ISNULL(CL2.Short,'') <> 'N')     
    LEFT JOIN Codelkup CL3 (NOLOCK) ON (PD.Storerkey = CL3.Storerkey AND CL3.Code = 'SHOWLOADKEYBARCODE'   
                                              AND CL3.Listname = 'REPORTCFG' AND CL3.Long = 'isp_batching_task_pickslip_09' AND ISNULL(CL3.Short,'') <> 'N')     
    LEFT JOIN Codelkup CL4 (NOLOCK) ON (PD.Storerkey = CL4.Storerkey AND CL4.Code = 'ShowCurrentDateTime'   
                                              AND CL4.Listname = 'REPORTCFG' AND CL4.Long = 'isp_batching_task_pickslip_09' AND ISNULL(CL4.Short,'') <> 'N')    
    LEFT JOIN Codelkup CL5 (NOLOCK) ON (PD.Storerkey = CL5.Storerkey AND CL5.Code = 'HideAltsku'   
                                              AND CL5.Listname = 'REPORTCFG' AND CL5.Long = 'isp_batching_task_pickslip_09' AND ISNULL(CL5.Short,'') <> 'N')  
    WHERE LP.Loadkey = @c_Loadkey  
    AND PT.TaskBatchNo = CASE WHEN @c_TaskBatchNo <> '' THEN @c_TaskBatchNo ELSE PT.TaskBatchNo END  
    AND L.Pickzone IN (SELECT PICKZONE FROM @PICKZONE)   --(CLVN01)
    AND RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) = @c_Mode  
    AND 1 = CASE WHEN (@c_ReportType = '3' AND @c_MultiConsoTaskPick = '1') OR (@c_ReportType = '5' AND @c_MultiConsoTaskPick <> '1') THEN 2 ELSE 1 END  
    GROUP BY PT.TaskBatchNo,   
             PD.Orderkey,  
             PD.Notes,   
             LP.Loadkey,  
             L.PickZone,  
             CASE WHEN ISNULL(CL.Long,'') <> '' THEN  
                CL.Long  
             ELSE RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) END,  
             RIGHT(RTRIM(ISNULL(PD.Notes,'')),1),  
             PD.Loc,  
             L.LogicalLocation,  
             PD.Sku,  
             SKU.Descr,  
             PACK.Casecnt,  
             CASE WHEN ISNULL(CL2.Code,'') <> '' THEN 'Y' ELSE 'N' END,              
             ISNULL(SKU.Style,''),     
             ISNULL(SKU.Size,'')    
            -- ,RIGHT(RTRIM(SKU.AltSKU),4)      
          ,  CASE WHEN @c_ReportType = '1' THEN SKU.AltSKU ELSE '' END     
          ,  CASE WHEN ISNULL(CL3.Code,'') <> '' THEN 'Y' ELSE 'N' END      
          ,  ISNULL(CL4.Short,'N')     
          ,  CASE WHEN @c_ReportType IN ('1','5')  THEN SKU.style + '-' + SKU.size ELSE '' END
          , CASE WHEN ISNULL(CL5.Code,'') <> '' THEN 'Y' ELSE 'N' END
                                
    IF @c_ReportType = '0'  
    BEGIN  
       SELECT DISTINCT TaskBatchNo, Mode, @c_Loadkey, @c_OrderCount, @c_PickZone,@c_PrintRemark as printremarks  
       FROM #TMP_TASK  
       ORDER BY Mode, TaskBatchNo  
    END  
      
    IF @c_ReportType = '1'  
    BEGIN        
          
       SELECT @n_StyleMaxLen = MAX(LEN(Style))  
       FROM #TMP_TASK  
                     
       IF ISNULL(@n_StyleMaxLen,0) < 15  
          SET @n_StyleMaxLen = 15  
         
       SELECT TaskBatchNo,   
              Notes,   
              Loadkey,   
              SUM(Qty) AS Qty,  
              CASE WHEN Mode = '5' THEN '' ELSE PickZone END AS PickZone,  
              ModeDesc,                
              Mode,  
              Loc,  
              LogicalLocation,  
              Sku,  
              CASE WHEN ShowStyleSize = 'Y' THEN    
                  RTRIM(Style) + SPACE(@n_StyleMaxLen-LEN(Style)) + ' ' + RTRIM(Size)  
              ELSE  
                  Descr  
              END,  
              Casecnt,  
              (SELECT SUM(T.Qty) FROM #TMP_TASK T WHERE T.TaskBatchNo = #TMP_TASK.TaskBatchNo) AS TotalQty,  
              (SELECT COUNT(DISTINCT T.SKU) FROM #TMP_TASK T WHERE T.TaskBatchNo = #TMP_TASK.TaskBatchNo) AS TotalSku,  
              ShowStyleSize     
            , Altsku  AS Altsku                    
            , Showloadkeybarcode        
            , ShowCurrentDateTime    
            , @c_printflag as PrintRemarks  
            , BuildOptDescr     
            , stylesize --, CASE WHEN HideAltsku = 'N' THEN stylesize ELSE '' END AS stylesize
            , HideAltsku
        FROM #TMP_TASK       
        GROUP BY TaskBatchNo,  
                 Notes,   
                 Loadkey,   
                 CASE WHEN Mode = '5' THEN '' ELSE PickZone END,  
                 Mode,  
                 ModeDesc,  
                 Loc,  
                 LogicalLocation,  
                 Sku,  
                 CASE WHEN ShowStyleSize = 'Y' THEN    
                      RTRIM(Style) + SPACE(@n_StyleMaxLen-LEN(Style)) + ' ' + RTRIM(Size)  
                 ELSE  
                     Descr  
                 END,  
                 Casecnt,  
                 ShowStyleSize    
                , Altsku                 
                , Showloadkeybarcode    
                , ShowCurrentDateTime       
                , PrintRemarks  
                , BuildOptDescr 
                , stylesize , HideAltsku  
         ORDER BY TaskBatchNo, LogicalLocation, Loc, Sku                   
    END  
             
    IF @c_ReportType = '2'  
    BEGIN  
       IF ISNULL(@c_MultiConsoTaskPick,'') <> '1' --if not multi conso pick (discrete)  
       BEGIN  
          WHILE @@TRANCOUNT > 0  
            COMMIT  
            
          BEGIN TRAN    
            
          DECLARE Cur_Task CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
             SELECT DISTINCT TaskBatchNo  
             FROM #TMP_TASK  
             ORDER BY TaskBatchNo  
             
          OPEN Cur_Task  
           FETCH NEXT FROM Cur_Task INTO @c_TaskBatchNo  
             
           WHILE @@FETCH_STATUS <> -1   
            BEGIN  
                 EXEC isp_Batching_AssignCart  
                   @c_TaskBatchNo  
                  ,@b_Success  OUTPUT  
                  ,@n_Err      OUTPUT  
                  ,@c_ErrMsg   OUTPUT     
                    
              FETCH NEXT FROM Cur_Task INTO @c_TaskBatchNo  
            END  
            CLOSE Cur_Task  
           DEALLOCATE Cur_Task                     
            
          WHILE @@TRANCOUNT > 0  
             COMMIT  
       END     
  
       SELECT TaskBatchNo,   
              Notes,   
              Loadkey,   
              PickZone,  
              ModeDesc,                
              Mode,  
              (SELECT SUM(T.Qty) FROM #TMP_TASK T WHERE T.TaskBatchNo = #TMP_TASK.TaskBatchNo) AS TotalQty,  
              (SELECT COUNT(DISTINCT T.SKU) FROM #TMP_TASK T WHERE T.TaskBatchNo = #TMP_TASK.TaskBatchNo) AS TotalSku,  
              @c_loadkey,                
              @c_ordercount,  
              @c_pickzone,  
              @c_MultiConsoTaskPick   
             , Altsku                 
             , Showloadkeybarcode         
             , ShowCurrentDateTime    
             , @c_printflag as PrintRemarks  
             , BuildOptDescr        
        FROM #TMP_TASK       
        GROUP BY TaskBatchNo,  
                 Notes,   
                 Loadkey,   
                 PickZone,  
                 ModeDesc,  
                 Mode  
                , Altsku                  
                , Showloadkeybarcode    
                , ShowCurrentDateTime       
                , PrintRemarks  
                , BuildOptDescr     
         ORDER BY TaskBatchNo  
    END  
      
    IF @c_ReportType = '3'  
    BEGIN  
       SELECT T.TaskBatchNo,  
              T.Loc,  
              T.LogicalLocation,                 
              T.Sku,  
              '*' + RTRIM(T.Sku) + '*' AS SkuBarcode,  
              T.Descr,  
              T.Orderkey,  
              (SELECT SUM(PD.Qty) FROM PICKDETAIL PD (NOLOCK) WHERE PD.Orderkey = T.Orderkey) AS OrderQty,  
              PT.LogicalName,  
              SUM(T.Qty) AS Qty  
            , Altsku                  
            , Showloadkeybarcode    
       INTO #TMP_RESULT        
       FROM #TMP_TASK T        
       JOIN PACKTASK PT (NOLOCK) ON T.Orderkey = PT.Orderkey AND T.TaskBatchNo = PT.TaskBatchNo          
       GROUP BY T.TaskBatchNo,  
                T.Loc,  
                T.LogicalLocation,               
                T.Sku,  
                '*' + RTRIM(T.Sku) + '*',  
                T.Descr,  
                T.Orderkey,  
                PT.LogicalName   
              , Altsku                   
              , Showloadkeybarcode         
       ORDER BY T.LogicalLocation, T.Loc, T.Sku         
         
       DECLARE Cur_SplitTask CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
          SELECT Orderkey, Sku, Loc, Qty  
          FROM #TMP_RESULT  
          WHERE Qty > 1             
          ORDER BY Sku, Orderkey  
                       
       OPEN Cur_SplitTask  
        FETCH NEXT FROM Cur_SplitTask INTO @c_Orderkey, @c_Sku, @c_Loc, @n_Qty  
          
        WHILE @@FETCH_STATUS <> -1   
         BEGIN  
             WHILE (@n_Qty - 1) > 0  
             BEGIN  
                 INSERT INTO #TMP_RESULT (TaskBatchNo, Loc, LogicalLocation, Sku, SkuBarcode, Descr, Orderkey, OrderQty, LogicalName, Qty,altsku,Showloadkeybarcode)     
                    SELECT TaskBatchNo, Loc, LogicalLocation, Sku, SkuBarcode, Descr, Orderkey, OrderQty, LogicalName, 1,altsku,Showloadkeybarcode             
                    FROM #TMP_RESULT   
                    WHERE Orderkey = @c_Orderkey  
                    AND Sku = @c_Sku  
                    AND Loc = @c_Loc  
                    AND Qty > 1                  
                   
                 SET @n_Qty = @n_Qty - 1                  
             END  
               
            FETCH NEXT FROM Cur_SplitTask INTO @c_Orderkey, @c_Sku, @c_Loc, @n_Qty  
         END  
         CLOSE Cur_SplitTask  
        DEALLOCATE Cur_SplitTask                      
          
        SELECT TaskBatchNo, Loc, LogicalLocation, Sku, SkuBarcode, Descr, Orderkey, OrderQty, LogicalName,altsku,Showloadkeybarcode      
        FROM #TMP_RESULT  
        ORDER BY LogicalLocation, Loc, Sku       
    END                    
  
    IF @c_ReportType = '4'  
    BEGIN  
       SELECT T.Pickzone,  
              SUM(T.Qty) AS TotalQty,  
              COUNT(DISTINCT T.Sku) AS TotalSku  
        FROM #TMP_TASK T        
        GROUP BY T.Pickzone  
        ORDER BY T.PickZone  
    END                 
      
    IF @c_ReportType = '5'  
    BEGIN  
          
       SELECT @n_StyleMaxLen = MAX(LEN(Style))  
       FROM #TMP_TASK  
        
       IF ISNULL(@n_StyleMaxLen,0) < 15  
       SET @n_StyleMaxLen = 15  
        
       SELECT SUM(TTS.Qty) AS Qty,  
              TTS.Loc,  
              TTS.LogicalLocation,  
              TTS.Sku,  
              CASE WHEN ShowStyleSize = 'Y' THEN    
                  RTRIM(TTS.Style) + SPACE(@n_StyleMaxLen-LEN(TTS.Style)) + ' ' + RTRIM(TTS.Size)  
              ELSE  
                  TTS.Descr  
              END,  
              TTS.Casecnt,  
              ShowStyleSize    
            , RIGHT(RTRIM(S.AltSKU),4) as Altsku           
            , Showloadkeybarcode    
            , ShowCurrentDateTime  
            , TTS.stylesize     
       FROM #TMP_TASK TTS  
       JOIN SKU S WITH (NOLOCK) ON S.sku=TTS.sku AND  s.storerkey=@c_Storerkey           
       GROUP BY TTS.Loc,  
                TTS.LogicalLocation,  
                TTS.Sku,  
                CASE WHEN ShowStyleSize = 'Y' THEN    
                  RTRIM(TTS.Style) + SPACE(@n_StyleMaxLen-LEN(TTS.Style)) + ' ' + RTRIM(TTS.Size)  
                ELSE  
                  TTS.Descr  
                END,  
                TTS.Casecnt,  
                ShowStyleSize    
              , RIGHT(RTRIM(S.AltSKU),4)--,Altsku           
              , Showloadkeybarcode    
              , ShowCurrentDateTime    
              , TTS.stylesize    
       ORDER BY TTS.LogicalLocation, TTS.Loc, TTS.Sku        
    END     
  
Quit:  
  
    WHILE @@TRANCOUNT < @n_StartTCnt  
       BEGIN TRAN  
           
    IF @n_Continue=3  -- Error Occured - Process And Return    
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
       EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_batching_task_pickslip_09'    
         --RAISERROR @n_Err @c_ErrMsg    
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
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
END /* main procedure */  

GO