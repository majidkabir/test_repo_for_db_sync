SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store Procedure:  isp_batching_task_pickslip_02                      */  
/* Creation Date:  14-JAN-2019                                          */  
/* Copyright: LF                                                        */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-7622-[CN] H&M picking list task report CR               */  
/*                                                                      */  
/* Input Parameters:                                                    */  
/*                                                                      */  
/* Output Parameters:  None                                             */  
/*                                                                      */  
/* Return Status:  None                                                 */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Local Variables:                                                     */  
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.6                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver.  Purposes                                  */  
/* 29-JAN-2019 CSCHONG  1.0   Fix Sorting issue (CS01)                  */  
/* 14-MAY-2019 CSCHONG  1.1   WMS-9042-revised report logic (CS01)      */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_batching_task_pickslip_02] (  
            @c_Loadkey NVARCHAR(10)  
           ,@c_OrderCount NVARCHAR(10) = '9999'  
           ,@c_TaskBatchNo NVARCHAR(10) = ''  
           ,@c_Pickzone NVARCHAR(4000) = ''  --INC0152000  
           ,@c_Mode NVARCHAR(10) = ''  -- 1=Multi-S 4=Multi-M 5=BIG 9=Single   
           ,@c_ReportType NVARCHAR(10) = '0' -- 0=Main   1=Single & BIG   2=Multi S & M   3=Sub report of Multi S & M(pick detail)  4=Sub report of Multi S & M(zone summary)   
           ,@c_ReGen NVARCHAR(10) = 'N' --Regnerate flag Y/N           -- 5=Sub report of Multi S & M(Conso Pick when MultiConsoTaskPick=1)                                               
           ,@c_updatepick  NCHAR(1) = 'N' --(Wan02)  
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
           ,@c_DelimiterSign       NVARCHAR(5)  
           ,@c_Delimiter           NVARCHAR(1)  
           ,@c_GetMode             NVARCHAR(20)   
           ,@n_SeqNo               INT  
           ,@c_ColValue            NVARCHAR(4000)   
           ,@n_CtnOrder            INT  
       
    SET @c_Delimiter       = ','     
    SET @c_GetMode         = ''  
    SET @n_CtnOrder        = 0  
  
    IF ISNULL(@c_Pickzone,'') = ''  
    BEGIN  
      SET @c_Pickzone = 'ALL'  
    END  
  
    --      IF ISNULL(@c_mode,'') = ''  
    --BEGIN  
    --  SET @c_mode = 'Mix'  
    --END  
            
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
       SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Invalid Mode. The value must be 1,4,5,9 (isp_batching_task_pickslip_02)'   
       GOTO Quit  
    END  
         
    IF @c_PickZone = 'ALL'  
    BEGIN  
      SELECT @c_ZoneList = @c_ZoneList + RTRIM(Loc.PickZone) + ','  
      FROM ORDERS O (NOLOCK)  
      JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey       
      JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc  
      WHERE O.Loadkey = @c_Loadkey  
      GROUP BY LOC.PickZone  
      ORDER BY LOC.PickZone  
        
      IF ISNULL(@c_ZoneList,'') <> ''  
      BEGIN  
          SET @c_ZoneList = LEFT(@c_ZoneList, LEN(RTRIM(@c_ZoneList)) - 1)  
          SET @c_PickZone = @c_ZoneList  
      END  
    END         
  
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
      
    --IF @c_ReportType = '0'  
    --BEGIN  
        
       IF @c_ReGen = 'Y'  
          SET @c_CallSource = 'RPTREGEN'  
       ELSE  
          SET @c_CallSource = 'RPT'     
  
       WHILE @@TRANCOUNT > 0  
         COMMIT  
  
  
  --   IF ISNULL(@c_mode,'') = 'Mix'  
  --BEGIN  
  
  -- SET @c_GetMode = '5,9'  
  
  --END  
  
 /* DECLARE C_DelimSplit CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT SeqNo, ColValue   
         FROM dbo.fnc_DelimSplit(@c_Delimiter,@c_GetMode)  
  
         OPEN C_DelimSplit  
         FETCH NEXT FROM C_DelimSplit INTO @n_SeqNo, @c_ColValue  
  
        WHILE (@@FETCH_STATUS=0)   
        BEGIN  
  
        BEGIN TRAN    
  
      --(Wan02) - START  
      EXEC ispOrderBatching  
          @c_LoadKey     = @c_LoadKey  
         ,@n_OrderCount  = @n_OrderCount    
         ,@c_PickZones   = @c_PickZone  
         ,@c_Mode        = @c_ColValue  
         ,@b_Success     = @b_Success   OUTPUT    
         ,@n_Err         = @n_Err       OUTPUT    
         ,@c_ErrMsg      = @c_ErrMsg    OUTPUT  
         ,@c_CallSource  = @c_CallSource  
         ,@c_updatepick  = @c_updatepick  
      --(Wan02) - END  
             
       IF @b_Success = 0  
       BEGIN  
          ROLLBACK  
                     
          SELECT @n_Continue = 3   
          GOTO Quit  
       END    
         
       WHILE @@TRANCOUNT > 0  
          COMMIT  
    --END   
   
 FETCH NEXT FROM C_DelimSplit INTO @n_SeqNo, @c_ColValue  
    END -- WHILE (@@FETCH_STATUS <> -1) AND @n_Continue <> 3  
  
    CLOSE C_DelimSplit  
    DEALLOCATE C_DelimSplit  */  
   
 --END  
  
  BEGIN TRAN    
  
      --(Wan02) - START  
      EXEC ispOrderBatching  
          @c_LoadKey     = @c_LoadKey  
         ,@n_OrderCount = @n_OrderCount    
         ,@c_PickZones   = @c_PickZone  
         ,@c_Mode        = @c_Mode  
         ,@b_Success     = @b_Success   OUTPUT    
         ,@n_Err         = @n_Err       OUTPUT    
         ,@c_ErrMsg      = @c_ErrMsg    OUTPUT  
         ,@c_CallSource  = @c_CallSource  
         ,@c_updatepick  = @c_updatepick  
      --(Wan02) - END  
  
 SET @n_CtnOrder = 0  
   
 SELECT @n_CtnOrder = COUNT(DISTINCT O.Orderkey)  
 FROM ORDERS O (NOLOCK)  
 JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey       
 WHERE O.Loadkey = @c_Loadkey            
  
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
           , AltSku = UPC.UPC  
           ,OD.Notes2 AS ODNotes2  
           ,RTRIM(SKU.BUSR7) as SkuBusr7  
           ,OD.Notes AS ODNotes   
           ,LEFT(PD.Loc,2) as LOCGRP  
    INTO #TMP_TASK  
    FROM LOADPLANDETAIL LP (NOLOCK)  
    JOIN PICKDETAIL PD (NOLOCK) ON LP.orderkey = PD.OrderKey  
    JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.StorerKey=PD.Storerkey AND OD.OrderKey=PD.OrderKey AND OD.OrderLineNumber=PD.OrderLineNumber   
                           AND OD.Sku = PD.Sku  
    JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku  
    JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey   
    JOIN LOC L (NOLOCK) ON PD.Loc = L.Loc  
    JOIN PACKTASK PT (NOLOCK) ON PD.Orderkey = PT.Orderkey  
    LEFT JOIN CODELKUP CL ON RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) = CL.Code AND CL.Listname = 'BATCHMODE'   
    LEFT JOIN Codelkup CL2 (NOLOCK) ON (PD.Storerkey = CL2.Storerkey AND CL2.Code = 'SHOWSTYLESIZE'   
                                              AND CL2.Listname = 'REPORTCFG' AND CL2.Long = 'r_dw_batching_task_pickslip02' AND ISNULL(CL2.Short,'') <> 'N')    
    LEFT JOIN UPC UPC WITH (NOLOCK) ON UPC.storerkey = Sku.storerkey AND UPC.SKU = SKU.SKU   
    WHERE LP.Loadkey = @c_Loadkey  
    AND PT.TaskBatchNo = CASE WHEN @c_TaskBatchNo <> '' THEN @c_TaskBatchNo ELSE PT.TaskBatchNo END  
    AND L.Pickzone IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_PickZone))   
    AND RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) = @c_Mode  
    AND 1 = CASE WHEN (@c_ReportType = '3' AND @c_MultiConsoTaskPick = '1') OR (@c_ReportType = '5' AND @c_MultiConsoTaskPick <> '1') THEN 2 ELSE 1 END  
 --AND L.locationtype = 'PICK'                            --CS01  Start
    AND LP.LoadKey NOT IN (  
                           SELECT DISTINCT b.LoadKey FROM dbo.PICKDETAIL a (NOLOCK) 
                           INNER JOIN orders b (NOLOCK) ON a.OrderKey=b.OrderKey INNER JOIN dbo.LOC c (NOLOCK) ON a.Loc=c.loc   
                           WHERE b.LoadKey=@c_Loadkey AND c.LocationType IN ('Other','Buffer') )  
  --CS01  end
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
             CASE WHEN ISNULL(CL2.Code,'') <> '' THEN 'Y' ELSE 'N' END,  --NJOW03           
             ISNULL(SKU.Style,''),  --NJOW03  
             ISNULL(SKU.Size,'') --NJOW03  
            ,UPC.UPC  
            ,OD.Notes2   
            ,SKU.BUSR7   
            ,OD.Notes  
            ,LEFT(PD.Loc,2)   
                                
    IF @c_ReportType = '0'  
    BEGIN  
       SELECT DISTINCT '' as TaskBatchNo, Mode, @c_Loadkey as loadkeyparm, @c_OrderCount as ordercountparm, 'ALL' as pickzoneparm  
       FROM #TMP_TASK  
       ORDER BY Mode, TaskBatchNo  
    END  
  
  
    IF @c_ReportType = '1'  
    BEGIN        
       --NJOW03  
       SELECT @n_StyleMaxLen = MAX(LEN(Style))  
       FROM #TMP_TASK  
                     
       IF ISNULL(@n_StyleMaxLen,0) < 15  
          SET @n_StyleMaxLen = 15  
         
       SELECT TaskBatchNo,   
              Notes,   
              Loadkey,   
              SUM(Qty) AS Qty,  
              PickZone,         --CS01  
              ModeDesc,                
              Mode,  
              Loc,  
              LogicalLocation,  
              Sku,  
              CASE WHEN ShowStyleSize = 'Y' THEN --NJOW03  
                  RTRIM(Style) + SPACE(@n_StyleMaxLen-LEN(Style)) + ' ' + RTRIM(Size)  
              ELSE  
                  Descr  
              END,  
              Casecnt,  
              (SELECT SUM(T.Qty) FROM #TMP_TASK T WHERE T.TaskBatchNo = #TMP_TASK.TaskBatchNo) AS TotalQty,  
              (SELECT COUNT(DISTINCT T.SKU) FROM #TMP_TASK T WHERE T.TaskBatchNo = #TMP_TASK.TaskBatchNo) AS TotalSku,  
              ShowStyleSize   
               ,Altsku       
               ,ODNotes2  
               ,SkuBusr7   
               ,ODNotes   
               ,'' AS Orderkey   
               ,LOCGRP              --CS01               
        FROM #TMP_TASK       
        GROUP BY TaskBatchNo,  
                 Notes,   
                 Loadkey,   
                 PickZone ,          --CS01  
                 Mode,  
                 ModeDesc,  
                 Loc,  
                 LogicalLocation,  
                 Sku,  
                 CASE WHEN ShowStyleSize = 'Y' THEN --NJOW03  
                      RTRIM(Style) + SPACE(@n_StyleMaxLen-LEN(Style)) + ' ' + RTRIM(Size)  
                 ELSE  
                     Descr  
                 END,  
                 Casecnt,  
                 ShowStyleSize  
                 ,Altsku     
                 ,ODNotes2  
                 ,SkuBusr7   
                 ,ODNotes   
                 ,LOCGRP              --CS01  
                 -- ,Orderkey             
          ORDER BY TaskBatchNo, LogicalLocation,LOCGRP, Loc, Sku      --CS01         
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
  
       SELECT TaskBatchNo as TaskBatchNo,   
              Notes as Notes,   
              Loadkey as Loadkey,   
              PickZone as PickZone,  
              ModeDesc as ModeDesc,                
              Mode as Mode,  
              (SELECT SUM(T.Qty) FROM #TMP_TASK T WHERE T.TaskBatchNo = #TMP_TASK.TaskBatchNo) AS TotalQty,  
              (SELECT COUNT(DISTINCT T.SKU) FROM #TMP_TASK T WHERE T.TaskBatchNo = #TMP_TASK.TaskBatchNo) AS TotalSku,  
              loc as loc,                
              sku as sku,  
              SUM(Qty) AS Qty,  
              @c_MultiConsoTaskPick as multiconsotaskpick   
              ,Altsku  as Altsku             
              ,ODNotes2 as ODNotes2  
              ,SkuBusr7  as SkuBusr7  
              ,ODNotes as ODNotes  
              ,''  as Orderkey                 --CS01  
              ,LogicalLocation as LogicalLocation  
              ,LOCGRP as locgrp              --CS01    
        INTO #TMP_TASK1             
        FROM #TMP_TASK       
        GROUP BY TaskBatchNo,  
                 Notes,   
                 Loadkey,   
                 PickZone,  
                 ModeDesc,  
                 Mode  
                 ,Altsku               
                 ,ODNotes2  
                 ,SkuBusr7   
                 ,ODNotes   
              -- ,Orderkey      --CS01  
                 ,loc                
                 , sku   
                 ,LogicalLocation  
                 ,LOCGRP              --CS01    
   ORDER BY TaskBatchNo, LogicalLocation,locgrp, Loc, Sku --CS01      
          --ORDER BY mode,              --CS01  
          --  TaskBatchNo,        --CS01  
          ----CASE WHEN Mode = '9' THEN Orderkey END    
          --  Loc,Altsku, SKU     --CS01  
  
    --select * from #TMP_TASK  
    --ORDER BY TaskBatchNo, LogicalLocation  
  
   select  TaskBatchNo ,   
           Notes,   
           Loadkey,   
           PickZone,  
           ModeDesc,                
           Mode,  
           TotalQty,  
           TotalSku,  
           loc,                
           sku,  
           Qty,  
           multiconsotaskpick   
           ,Altsku             
           ,ODNotes2  
           ,SkuBusr7   
           ,ODNotes   
           ,Orderkey  
           ,LOCGRP              --CS01    
   from #TMP_TASK1  
   ORDER BY TaskBatchNo, LogicalLocation,locgrp,loc,sku       --CS01  
  
  
    END  
      
    IF @c_ReportType = '3'  
    BEGIN  
       SELECT T.TaskBatchNo,  
              T.Loc,  
              T.LogicalLocation,                 
              T.Sku,  
              '*' + RTRIM(T.Sku) + '*' AS SkuBarcode,  
              T.Descr,  
              '' as Orderkey ,--T.Orderkey,          --CS01  
              (SELECT SUM(PD.Qty) FROM PICKDETAIL PD (NOLOCK) WHERE PD.Orderkey = T.Orderkey) AS OrderQty,  
              PT.LogicalName,  
              SUM(T.Qty) AS Qty  
              ,Altsku              
              ,ODNotes2  
              ,SkuBusr7   
              ,ODNotes   
              ,LOCGRP  as locgrp            --CS01      
       INTO #TMP_RESULT        
       FROM #TMP_TASK T        
       JOIN PACKTASK PT (NOLOCK) ON T.Orderkey = PT.Orderkey AND T.TaskBatchNo = PT.TaskBatchNo          
       GROUP BY T.TaskBatchNo,  
                T.Loc,  
                T.LogicalLocation,               
                T.Sku,  
                '*' + RTRIM(T.Sku) + '*',  
                T.Descr,  
              --  T.Orderkey,                     --CS01  
                PT.LogicalName   
                ,Altsku               
                ,ODNotes2  
                ,SkuBusr7   
                ,ODNotes        
                ,LOCGRP              --CS01    
       ORDER BY T.LogicalLocation,locgrp, T.Loc, T.Sku             --CS01    
         
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
                 INSERT INTO #TMP_RESULT (TaskBatchNo, Loc, LogicalLocation, Sku, SkuBarcode, Descr, Orderkey, OrderQty, LogicalName, Qty,altsku)--Cs01  
                    SELECT TaskBatchNo, Loc, LogicalLocation, Sku, SkuBarcode, Descr, Orderkey, OrderQty, LogicalName, 1,altsku       
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
          
        SELECT TaskBatchNo, Loc, LogicalLocation, Sku, SkuBarcode, Descr, Orderkey, OrderQty, LogicalName,altsku  
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
       --NJOW03  
       SELECT @n_StyleMaxLen = MAX(LEN(Style))  
       FROM #TMP_TASK  
        
       IF ISNULL(@n_StyleMaxLen,0) < 15  
          SET @n_StyleMaxLen = 15  
        
       SELECT SUM(TTS.Qty) AS Qty,  
              TTS.Loc,  
              TTS.LogicalLocation,  
              TTS.Sku,  
              CASE WHEN ShowStyleSize = 'Y' THEN --NJOW03  
                  RTRIM(TTS.Style) + SPACE(@n_StyleMaxLen-LEN(TTS.Style)) + ' ' + RTRIM(TTS.Size)  
              ELSE  
                  TTS.Descr  
              END,  
              TTS.Casecnt,  
              ShowStyleSize --NJOW03  
              , RIGHT(RTRIM(S.AltSKU),4) as Altsku         
              ,ODNotes2  
              ,SkuBusr7   
              ,ODNotes   
              ,'' as Orderkey-- ,Orderkey   --CS01  
              ,LOCGRP            --CS01  
       FROM #TMP_TASK TTS  
       JOIN SKU S WITH (NOLOCK) ON S.sku=TTS.sku AND  s.storerkey=@c_Storerkey           
       GROUP BY TTS.Loc,  
                TTS.LogicalLocation,  
                TTS.Sku,  
                CASE WHEN ShowStyleSize = 'Y' THEN --NJOW03  
                  RTRIM(TTS.Style) + SPACE(@n_StyleMaxLen-LEN(TTS.Style)) + ' ' + RTRIM(TTS.Size)  
                ELSE  
                  TTS.Descr  
                END,  
                TTS.Casecnt,  
                ShowStyleSize --NJOW03  
                ,RIGHT(RTRIM(S.AltSKU),4)--,Altsku          
                ,ODNotes2  
                ,SkuBusr7   
                ,ODNotes   
                 --  ,Orderkey         --CS01  
                ,LOCGRP             --CS01  
       ORDER BY TTS.LogicalLocation,TTS.LOCGRP, TTS.Loc, TTS.Sku      --CS01  
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
       EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispOrderBatching'    
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