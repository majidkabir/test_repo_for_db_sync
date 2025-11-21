SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store Procedure:  isp_batching_task_pickslip_08                      */  
/* Creation Date:  14-Jun-2023                                          */  
/* Copyright: Ma                                                        */  
/* Written by:CSCHONG                                                   */  
/*                                                                      */  
/* Purpose: WMS-22685[CN] Lululemon SCE View Report Add Ecom Task Summry*/  
/*          &Pickslip Reports CR                                        */  
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
/* 14/06/2023  CSCHONG   1.0  Devops Scripts Combine                    */  
/************************************************************************/  
  
CREATE    PROC [dbo].[isp_batching_task_pickslip_08] (  
            @c_Loadkey_from NVARCHAR(10)  
           ,@c_Loadkey_to NVARCHAR(10) = ''  
           ,@c_OrderCount NVARCHAR(10) = '9999'  
           ,@c_TaskBatchNo NVARCHAR(10) = ''  
           ,@c_Pickzone NVARCHAR(4000) = ''  --INC0152000  
           ,@c_Mode NVARCHAR(10) = ''  -- 1=Multi-S 4=Multi-M 5=BIG 9=Single  
           ,@c_ReportType NVARCHAR(10) = '0' -- 0=Main   1=Single & BIG   2=Multi S & M   3=Sub report of Multi S & M(pick detail)  4=Sub report of Multi S & M(zone summary)  
           ,@c_ReGen NVARCHAR(10) = 'N' --Regnerate flag Y/N           -- 5=Sub report of Multi S & M(Conso Pick when MultiConsoTaskPick=1)  
           ,@c_updatepick  NCHAR(5) = 'N'   
 )  
 AS  
 BEGIN  
    SET NOCOUNT ON  
    SET QUOTED_IDENTIFIER OFF  
    SET CONCAT_NULL_YIELDS_NULL OFF  
    SET ANSI_WARNINGS OFF  
  
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
  
    DECLARE @c_LogicalLocation   NVARCHAR(18)  
           ,@c_SkuBarcode         NVARCHAR(22)  
           ,@c_Descr              NVARCHAR(60)  
           ,@n_OrderQty           INT  
           ,@c_LogicalName        NVARCHAR(10)  
           ,@c_altsku             NVARCHAR(20)  
           ,@c_Showloadkeybarcode NVARCHAR(10)  
  
           ,@c_PickByVP           NVARCHAR(30)             
           ,@c_LPUDF10            NVARCHAR(20)    
           ,@c_loadkey            NVARCHAR(10)        
           ,@c_Getloadkey         NVARCHAR(10)   
           ,@n_ctnstorerkey       INT   = 0  
           ,@n_Maxorders          INT = 10000  
           ,@n_ctnord             INT = 0   
           ,@c_FromStorerkey      NVARCHAR(10)
           ,@c_ToStorerkey        NVARCHAR(10)
           ,@c_GetStorerkey       NVARCHAR(10)
  
    SELECT @b_Success = 1, @n_Err = 0, @c_Errmsg = '', @c_ZoneList = '', @n_StartTCnt = @@TRANCOUNT, @n_Continue = 1  
  
    IF ISNULL(@c_Loadkey_from,'') = ''  
    BEGIN  
          SELECT @n_Continue = 3  
          SELECT @n_Err = 63220  
          SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': From Loadkey blank (isp_batching_task_pickslip_08)'  
          GOTO Quit  
    END   
    ELSE  
    BEGIN  
       IF ISNULL(@c_Loadkey_to,'') = ''  
       BEGIN  
         SET @c_Loadkey_to = @c_Loadkey_from  
       END  
    END  


    SELECT TOP 1 @c_FromStorerkey = OH.storerkey
    FROM ORDERS OH WITH (NOLOCK)
    WHERE OH.LoadKey = @c_Loadkey_from

    SELECT TOP 1 @c_ToStorerkey = OH.storerkey
    FROM ORDERS OH WITH (NOLOCK)
    WHERE OH.LoadKey = @c_Loadkey_to

   IF @c_FromStorerkey <> @c_ToStorerkey
   BEGIN  
       SELECT @n_Continue = 3  
       SELECT @n_Err = 63220  
       SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': From storerkey and To storerkey is not same (isp_batching_task_pickslip_08)'  
       GOTO Quit  
   END
   ELSE
   BEGIN
       SET @c_GetStorerkey = @c_FromStorerkey
   END 

  
      CREATE TABLE #TMPLOADLIST  
      (  loadkey       NVARCHAR(10),  
         storerkey     NVARCHAR(10),  
         OrdCnt        INT,  
       Errmsg        NVARCHAR(250) NULL  
      )  
  
 CREATE TABLE #TMPLOADTASK  
      (  TaskBatchNo             NVARCHAR(10),  
         Orderkey                NVARCHAR(10),  
         Notes                   NVARCHAR(4000),  
       Loadkey                 NVARCHAR(10) ,  
         Qty                     INT,  
         Pickzone                NVARCHAR(10),  
         ModeDesc                NVARCHAR(250),  
         Mode                    NVARCHAR(4000),  
         LOC                     NVARCHAR(10),                 
         LogicalLocation         NVARCHAR(18),  
         Sku                     NVARCHAR(20),  
         Descr                   NVARCHAR(60),  
         CaseCnt                 FLOAT,  
         ShowStyleSize           NVARCHAR(1),  
         Style                   NVARCHAR(20),  
         [Size]                  NVARCHAR(10),  
         AltSku                  NVARCHAR(20),  
         Showloadkeybarcode      NVARCHAR(1),  
         ShowCurrentDateTime     NVARCHAR(5),  
         ShowVAS                 NVARCHAR(5),  
         VAS                     NVARCHAR(80),  
         Userdefine10            NVARCHAR(10),  
         ShowSalesman            NVARCHAR(1),  
         Salesman                NVARCHAR(30),    
         ShowCourier             NVARCHAR(1),     
         Shipperkey              NVARCHAR(15)     
      )  
  
   INSERT INTO #TMPLOADLIST  
   (  
       loadkey,  
       storerkey,  
       OrdCnt  
   )  
   SELECT DISTINCT O.loadkey,O.StorerKey,COUNT(DISTINCT O.OrderKey)  
   FROM dbo.ORDERS O WITH (NOLOCK)  
   WHERE O.LoadKey >= @c_Loadkey_from AND O.LoadKey <= @c_Loadkey_to  
   AND O.StorerKey = @c_GetStorerkey 
   GROUP BY O.loadkey,O.StorerKey  
  
  
   SELECT @n_ctnstorerkey = COUNT(DISTINCT storerkey)  
         ,@n_ctnord = SUM(OrdCnt)  
   FROM #TMPLOADLIST  
   WHERE LoadKey >= @c_Loadkey_from AND LoadKey <= @c_Loadkey_to   
   AND storerkey = @c_GetStorerkey
  
  
   IF @n_ctnord > @n_Maxorders  
   BEGIN  
       SELECT @n_Continue = 3  
       SELECT @n_Err = 63230  
       SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': No of orders retrieve more than maximun orders allow (isp_batching_task_pickslip_08)'  
       GOTO Quit  
   END  
      
  
    SELECT @n_OrderCount = CONVERT(INT, @c_OrderCount)  

  
    IF ISNULL(@c_PickZone,'') = ''  
       SET @c_PickZone = ''  
  
    IF ISNULL(@c_TaskBatchNo,'') = ''  
       SET @c_TaskBatchNo = ''  
  
    IF @c_Mode NOT IN('1','4','5','9')  
    BEGIN  
    SELECT @n_Continue = 3  
       SELECT @n_Err = 63200  
       SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Invalid Mode. The value must be 1,4,5,9 (isp_batching_task_pickslip_08)'  
       GOTO Quit  
    END  
  
  
   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT DISTINCT loadkey     
   FROM   #TMPLOADLIST   
   WHERE storerkey = @c_GetStorerkey
    
    
   OPEN CUR_RESULT     
       
   FETCH NEXT FROM CUR_RESULT INTO @c_GetLoadkey      
       
   WHILE @@FETCH_STATUS <> -1    
   BEGIN     
  
    IF @c_PickZone = 'ALL'  
    BEGIN  
      SELECT @c_ZoneList = @c_ZoneList + RTRIM(Loc.PickZone) + ','  
      FROM ORDERS O (NOLOCK)  
      JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey  
      JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc  
      WHERE O.Loadkey = @c_GetLoadkey  
      GROUP BY LOC.PickZone  
      ORDER BY LOC.PickZone  
  
      IF ISNULL(@c_ZoneList,'') <> ''  
      BEGIN  
          SET @c_ZoneList = LEFT(@c_ZoneList, LEN(RTRIM(@c_ZoneList)) - 1)  
          SET @c_PickZone = @c_ZoneList  
      END  
    END  
  
   SELECT TOP 1 @c_Storerkey = Storerkey,  
                @c_Facility = Facility  
       FROM ORDERS (NOLOCK)  
       WHERE Loadkey = @c_GetLoadkey  
  
    IF @c_ReportType IN ('2','3','5')  
    BEGIN  
  
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
  
      IF UPPER(@c_updatepick) = 'VP'  
      BEGIN  
                SET @c_PickByVP = ''  
                SET @c_LPUDF10 = ''  
  
                Execute nspGetRight  
                @c_facility,  
                @c_StorerKey,  
                '', --@c_Sku  
                'PickByVoicePicking', -- Configkey  
                @b_success            OUTPUT,  
                @c_PickByVP           OUTPUT,  
                @n_err                OUTPUT,  
                @c_errmsg             OUTPUT  
  
        IF ISNULL(@c_PickByVP,'') = '1'  
        BEGIN  
            SELECT @c_LPUDF10 = LP.Userdefine10  
            FROM LOADPLAN LP WITH (NOLOCK)  
            WHERE LP.Loadkey = @c_GetLoadkey  
  
            IF ISNULL(@c_LPUDF10,'') = ''  
            BEGIN  
  
                UPDATE Loadplan WITH (ROWLOCK)  
                SET Userdefine10 = UPPER(@c_updatepick)  
                  , EditWho    = SUSER_SNAME()  
                  , EditDate   = GETDATE()  
                    WHERE Loadplan.loadkey = @c_GetLoadkey  
  
                SELECT @n_err = @@ERROR  
  
                IF @n_err <> 0  
                BEGIN  
                  SELECT @n_Continue = 3  
                  SELECT @n_Err = 63210  
                  SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to Update Loadplan (isp_batching_task_pickslip_08)'  
                  GOTO Quit  
                END  
            END  
        END  
   END  

  
    IF @c_ReportType = '0'  
    BEGIN  
  
       IF @c_ReGen = 'Y'  
          SET @c_CallSource = 'RPTREGEN'  
       ELSE  
          SET @c_CallSource = 'RPT'  
  
       WHILE @@TRANCOUNT > 0  
         COMMIT  
  
       BEGIN TRAN  
  
      EXEC ispOrderBatching  
          @c_LoadKey     = @c_GetLoadkey  
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
  
    INSERT INTO #TMPLOADTASK  
    (  
        TaskBatchNo,  
        Orderkey,  
        Notes,  
        Loadkey,  
        Qty,  
        Pickzone,  
        ModeDesc,  
        Mode,  
        LOC,  
        LogicalLocation,  
        Sku,  
        Descr,  
        CaseCnt,  
        ShowStyleSize,  
        Style,  
        Size,  
        AltSku,  
        Showloadkeybarcode,  
        ShowCurrentDateTime,  
        ShowVAS,  
        VAS,  
        Userdefine10,  
        ShowSalesman,  
        Salesman,  
        ShowCourier,  
        Shipperkey  
    )  
  
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
           --,  
         , AltSku = CASE WHEN @c_ReportType = '1' THEN SKU.AltSKU ELSE '' END    
         , CASE WHEN ISNULL(CL3.Code,'') <> '' THEN 'Y' ELSE 'N' END AS Showloadkeybarcode    
         , ISNULL(CL4.Short,'N') AS ShowCurrentDateTime   
         , ISNULL(CL6.Short,'N') AS ShowVAS    
         , CASE WHEN ISNULL(CL6.Short,'N') = 'N' THEN '' ELSE (SELECT MAX(ISNULL(ORDERINFO.ORDERINFO01,'')) + MAX(ISNULL(ORDERINFO.ORDERINFO02,''))  
                                                               FROM ORDERINFO (NOLOCK) WHERE ORDERINFO.Orderkey = PD.Orderkey) END AS VAS    
         , CASE WHEN ISNULL(CL6.Short,'N') = 'N' THEN '' ELSE (SELECT MAX(ISNULL(Orders.Userdefine10,'')) FROM Orders (NOLOCK) WHERE Orders.Orderkey = PD.Orderkey) END AS Userdefine10     
         , ISNULL(CL5.Short,'N') AS ShowSalesman     
         , CASE WHEN ISNULL(CL5.Short,'N') = 'N' THEN '' ELSE (SELECT MAX(ISNULL(Orders.Salesman,'')) FROM Orders (NOLOCK) WHERE Orders.Orderkey = PD.Orderkey) END AS Salesman    
         , ISNULL(CL7.Short,'N') AS ShowCourier    
         , CASE WHEN ISNULL(CL7.Short,'N') = 'N' THEN '' ELSE (SELECT MAX(ISNULL(Orders.Shipperkey,'')) FROM Orders (NOLOCK) WHERE Orders.Orderkey = PD.Orderkey) END AS Shipperkey    
   -- INTO #TMP_TASK  
    FROM LOADPLANDETAIL LP (NOLOCK)  
    JOIN PICKDETAIL PD (NOLOCK) ON LP.orderkey = PD.OrderKey  
    JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku  
    JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey  
    JOIN LOC L (NOLOCK) ON PD.Loc = L.Loc  
    JOIN PACKTASK PT (NOLOCK) ON PD.Orderkey = PT.Orderkey  
    LEFT JOIN CODELKUP CL ON RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) = CL.Code AND CL.Listname = 'BATCHMODE'  
    LEFT JOIN Codelkup CL2 (NOLOCK) ON (PD.Storerkey = CL2.Storerkey AND CL2.Code = 'SHOWSTYLESIZE'  
                                              AND CL2.Listname = 'REPORTCFG' AND CL2.Long = 'r_dw_batching_task_pickslip_08' AND ISNULL(CL2.Short,'') <> 'N')    
    LEFT JOIN Codelkup CL3 (NOLOCK) ON (PD.Storerkey = CL3.Storerkey AND CL3.Code = 'SHOWLOADKEYBARCODE'  
                                              AND CL3.Listname = 'REPORTCFG' AND CL3.Long = 'r_dw_batching_task_pickslip_08' AND ISNULL(CL3.Short,'') <> 'N')   
    LEFT JOIN Codelkup CL4 (NOLOCK) ON (PD.Storerkey = CL4.Storerkey AND CL4.Code = 'ShowCurrentDateTime'  
                                              AND CL4.Listname = 'REPORTCFG' AND CL4.Long = 'r_dw_batching_task_pickslip_08' AND ISNULL(CL4.Short,'') <> 'N')   
    LEFT JOIN Codelkup CL5 (NOLOCK) ON (PD.Storerkey = CL5.Storerkey AND CL5.Code = 'ShowSalesman'  
                                              AND CL5.Listname = 'REPORTCFG' AND CL5.Long = 'r_dw_batching_task_pickslip_08' AND ISNULL(CL5.Short,'') <> 'N')   
    LEFT JOIN Codelkup CL6 (NOLOCK) ON (PD.Storerkey = CL6.Storerkey AND CL6.Code = 'ShowVAS'  
                                              AND CL6.Listname = 'REPORTCFG' AND CL6.Long = 'r_dw_batching_task_pickslip_08' AND ISNULL(CL6.Short,'') <> 'N')    
    LEFT JOIN Codelkup CL7 (NOLOCK) ON (PD.Storerkey = CL7.Storerkey AND CL7.Code = 'ShowCourier'  
                                              AND CL7.Listname = 'REPORTCFG' AND CL7.Long = 'r_dw_batching_task_pickslip_08' AND ISNULL(CL7.Short,'') <> 'N')    
    WHERE LP.Loadkey = @c_GetLoadkey  
    AND PT.TaskBatchNo = CASE WHEN @c_TaskBatchNo <> '' THEN @c_TaskBatchNo ELSE PT.TaskBatchNo END  
    AND L.Pickzone IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_PickZone))  
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
            -- ,  
          ,  CASE WHEN @c_ReportType = '1' THEN SKU.AltSKU ELSE '' END    
          ,  CASE WHEN ISNULL(CL3.Code,'') <> '' THEN 'Y' ELSE 'N' END    
          ,  ISNULL(CL4.Short,'N')    
          ,  ISNULL(CL6.Short,'N')   
          ,  ISNULL(CL5.Short,'N')   
          ,  ISNULL(CL7.Short,'N')   
  
  
      FETCH NEXT FROM CUR_RESULT INTO @c_GetLoadkey      
      END  
  
      CLOSE CUR_RESULT  
      DEALLOCATE CUR_RESULT  
  
--SELECT * FROM #TMPLOADTASK  
  
    IF @c_ReportType = '0'  
    BEGIN  
       SELECT DISTINCT TaskBatchNo, Mode, LoadKey, @c_OrderCount, @c_PickZone,altsku  
       FROM #TMPLOADTASK  
       ORDER BY LoadKey,Mode, TaskBatchNo  
    END  
  
    IF @c_ReportType = '1'  
    BEGIN  
  
       SELECT @n_StyleMaxLen = MAX(LEN(Style))  
       FROM #TMPLOADTASK  
       WHERE LoadKey = @c_Loadkey_from  
  
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
              (SELECT SUM(T.Qty) FROM #TMPLOADTASK T WHERE T.TaskBatchNo = #TMPLOADTASK.TaskBatchNo AND loadkey = @c_Loadkey_from) AS TotalQty,  
              (SELECT COUNT(DISTINCT T.SKU) FROM #TMPLOADTASK T WHERE T.TaskBatchNo = #TMPLOADTASK.TaskBatchNo AND loadkey = @c_Loadkey_from) AS TotalSku,  
              ShowStyleSize   
            , Altsku              
            , Showloadkeybarcode   
            , ShowCurrentDateTime    
            , ShowVAS       
            , VAS             
            , Userdefine10    
            , ShowSalesman    
            , Salesman       
            , ShowCourier     
            , Shipperkey     
        FROM #TMPLOADTASK  
        WHERE LoadKey = @c_Loadkey_from  
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
                , ShowVAS        
                , VAS         
                , Userdefine10    
                , ShowSalesman   
                , Salesman        
                , ShowCourier   
                , Shipperkey      
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
             FROM #TMPLOADTASK  
             WHERE LoadKey = @c_Loadkey_from  
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
              (SELECT SUM(T.Qty) FROM #TMPLOADTASK T WHERE T.TaskBatchNo = #TMPLOADTASK.TaskBatchNo AND T.loadkey = @c_Loadkey_from) AS TotalQty,  
              (SELECT COUNT(DISTINCT T.SKU) FROM #TMPLOADTASK T WHERE T.TaskBatchNo = #TMPLOADTASK.TaskBatchNo AND T.loadkey = @c_Loadkey_from) AS TotalSku,  
              loadkeyparm = @c_Loadkey_from,  
              ordercountparm = @c_ordercount,  
              pickzoneparm = @c_pickzone,  
              multiconsotaskpick = @c_MultiConsoTaskPick  
             , Altsku              
             , Showloadkeybarcode   
             , ShowCurrentDateTime    
             , ShowVAS       
             , VAS             
             , Userdefine10   
             , ShowSalesman    
             , Salesman        
             , ShowCourier     
             , Shipperkey      
        FROM #TMPLOADTASK  
        WHERE LoadKey = @c_Loadkey_from  
        GROUP BY TaskBatchNo,  
                 Notes,  
                 Loadkey,  
                 PickZone,  
                 ModeDesc,  
                 Mode  
                , Altsku               
                , Showloadkeybarcode   
                , ShowCurrentDateTime   
                , ShowVAS        
                , VAS             
                , Userdefine10    
                , ShowSalesman    
                , Salesman      
                , ShowCourier     
                , Shipperkey     
         ORDER BY LoadKey,TaskBatchNo  
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
            , T.LoadKey AS loadkey  
       INTO #TMP_RESULT  
       FROM #TMPLOADTASK T  
       JOIN PACKTASK PT (NOLOCK) ON T.Orderkey = PT.Orderkey AND T.TaskBatchNo = PT.TaskBatchNo  
       WHERE T.LoadKey = @c_Loadkey_from  
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
              , T.LoadKey   
       ORDER BY T.LoadKey,T.LogicalLocation, T.Loc, T.Sku  
  
       DECLARE Cur_SplitTask CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
          SELECT Orderkey, Sku, Loc, Qty,  
                 TaskBatchNo, LogicalLocation, SkuBarcode, Descr, OrderQty, LogicalName, altsku, Showloadkeybarcode   
          FROM #TMP_RESULT  
          WHERE Qty > 1   
          AND loadkey = @c_Loadkey_from  
          ORDER BY Sku, Orderkey  
  
       OPEN Cur_SplitTask  
        FETCH NEXT FROM Cur_SplitTask INTO @c_Orderkey, @c_Sku, @c_Loc, @n_Qty  
                                          ,@c_TaskBatchNo, @c_LogicalLocation, @c_SkuBarcode, @c_Descr, @n_OrderQty, @c_LogicalName, @c_altsku, @c_Showloadkeybarcode  
  
        WHILE @@FETCH_STATUS <> -1  
         BEGIN  
             WHILE (@n_Qty - 1) > 0  
             BEGIN  
                 INSERT INTO #TMP_RESULT (TaskBatchNo, Loc, LogicalLocation, Sku, SkuBarcode, Descr, Orderkey, OrderQty, LogicalName, Qty,altsku,Showloadkeybarcode,loadkey)  
                              VALUES (@c_TaskBatchNo, @c_Loc, @c_LogicalLocation, @c_Sku, @c_SkuBarcode, @c_Descr, @c_Orderkey, @n_OrderQty, @c_LogicalName, 1, @c_altsku, @c_Showloadkeybarcode,@c_Loadkey_from)    
  
                 SET @n_Qty = @n_Qty - 1  
             END  
  
            FETCH NEXT FROM Cur_SplitTask INTO @c_Orderkey, @c_Sku, @c_Loc, @n_Qty  
                                              ,@c_TaskBatchNo, @c_LogicalLocation, @c_SkuBarcode, @c_Descr, @n_OrderQty, @c_LogicalName, @c_altsku, @c_Showloadkeybarcode    
  
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
              COUNT(DISTINCT T.Sku) AS TotalSku,  
              MAX(ShowCourier)     
        FROM #TMPLOADTASK T  
        WHERE T.LoadKey = @c_Loadkey_from  
        GROUP BY T.Pickzone  
        ORDER BY T.PickZone  
    END  
  
    IF @c_ReportType = '5'  
    BEGIN  
  
       SELECT @n_StyleMaxLen = MAX(LEN(Style))  
       FROM #TMPLOADTASK  
       WHERE LoadKey = @c_Loadkey_from  
  
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
            , ShowVAS         
            , VAS             
            , Userdefine10    
            , ShowSalesman    
            , Salesman        
            , ShowCourier     
            , Shipperkey      
       FROM #TMPLOADTASK TTS  
       JOIN SKU S WITH (NOLOCK) ON S.sku=TTS.sku AND  s.storerkey=@c_Storerkey  
       WHERE TTS.LoadKey = @c_Loadkey_from  
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
              , RIGHT(RTRIM(S.AltSKU),4)  
              , Showloadkeybarcode   
              , ShowCurrentDateTime   
              , ShowVAS         
              , VAS             
              , Userdefine10    
              , ShowSalesman    
              , Salesman        
              , ShowCourier    
              , Shipperkey      
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