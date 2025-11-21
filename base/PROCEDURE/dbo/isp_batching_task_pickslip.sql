SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_batching_task_pickslip                         */
/* Creation Date:  12-Jan-2016                                          */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 361158-CN-Batching order - Task pickslip report             */
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
/* 23/08/2016  NJOW01   1.0   361158-Add Conso pickslip for multi-s/m   */
/*                            by config                                 */
/* 23/08/2016  NJOW02   1.1   375824-add parameter for re-gen batch     */
/* 19/10/2016  NJOW03   1.2   361158-Replace desc with sytle,size by    */
/*                            config                                    */
/* 29-06/2017  CSCHONG  1.3   WMS-2144-Add new field (CS01)             */
/* 29-08/2017  Wan01    1.4   WMS-2509 - [CR] CN C&A Task PickSlip Report*/
/*                            _Single                                   */
/* 28-03-2018  SPChin   1.5   INC0152000 - Bug Fixed                    */
/* 03-04-2018  Wan02    1.6   WMS-4263 - [CN] MAST Bulk Inventory - Order*/
/*                            Selection Summary Report CR               */
/* 12-04-2019  CSCHONG  1.7   WMS-8631-add report config (CS02)         */
/* 27-12-2019  WLChooi  1.8   WMS-11616 - Add ReportCFG to show current */
/*                            datetime (WL01)                           */
/* 22-06-2020  WLChooi  1.9   WMS-13833 - Add ReportCFG to show VAS and */
/*                            Userdefine10 (WL02)                       */
/* 05-06-2020  WLChooi  2.0   WMS-13654 - Add ReportCFG to show Salesman*/
/*                            (WL03)                                    */
/* 26-10-2020  NJOW04   2.1   Performance tuning.                       */
/* 12-JAN-2020 CSCHONG  2.2   WMS-16010 add config (CS03)               */
/* 05-04-2021  WLChooi  2.3   WMS-16752 Add ReportCFG to show Shipperkey*/
/*                            (WL04)                                    */
/* 10-05-2022  KuanYee  2.4   INC1802488-BugFixed                       */
/*                            Add Stuff() show all PickZone(KY01)       */  
/************************************************************************/

CREATE PROC [dbo].[isp_batching_task_pickslip] (
            @c_Loadkey NVARCHAR(10)
           ,@c_OrderCount NVARCHAR(10) = '9999'
           ,@c_TaskBatchNo NVARCHAR(10) = ''
           ,@c_Pickzone NVARCHAR(4000) = ''  --INC0152000
           ,@c_Mode NVARCHAR(10) = ''  -- 1=Multi-S 4=Multi-M 5=BIG 9=Single
           ,@c_ReportType NVARCHAR(10) = '0' -- 0=Main   1=Single & BIG   2=Multi S & M   3=Sub report of Multi S & M(pick detail)  4=Sub report of Multi S & M(zone summary) 
           ,@c_ReGen NVARCHAR(10) = 'N' --Regnerate flag Y/N           -- 5=Sub report of Multi S & M(Conso Pick when MultiConsoTaskPick=1)                                             
           ,@c_updatepick  NCHAR(5) = 'N' --(Wan02)
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
           ,@n_StyleMaxLen         INT --NJOW01       
           
    --NJOW04
    DECLARE @c_LogicalLocation    NVARCHAR(18)
           ,@c_SkuBarcode         NVARCHAR(22) 
           ,@c_Descr              NVARCHAR(60)
           ,@n_OrderQty           INT
           ,@c_LogicalName        NVARCHAR(10)
           ,@c_altsku             NVARCHAR(20)
           ,@c_Showloadkeybarcode NVARCHAR(10)

           ,@c_PickByVP           NVARCHAR(30)             --CS03
           ,@c_LPUDF10            NVARCHAR(20)             --CS03
          
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
       SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Invalid Mode. The value must be 1,4,5,9 (isp_batching_task_pickslip)' 
       GOTO Quit
    END
       
    IF @c_PickZone = 'ALL'
    BEGIN
      --SELECT @c_ZoneList = @c_ZoneList + RTRIM(Loc.PickZone) + ','      
      SELECT @c_ZoneList = STUFF((SELECT ',' + RTRIM(Loc.PickZone)     --KY01        
      FROM ORDERS O (NOLOCK)
      JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey     
      JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
      WHERE O.Loadkey = @c_Loadkey
      GROUP BY LOC.PickZone
      --ORDER BY LOC.PickZone      
      ORDER BY LOC.PickZone FOR XML PATH('')),1,1,'' ) + ','   --KY01     
           
      IF ISNULL(@c_ZoneList,'') <> ''
      BEGIN
          SET @c_ZoneList = LEFT(@c_ZoneList, LEN(RTRIM(@c_ZoneList)) - 1)
          SET @c_PickZone = @c_ZoneList
      END
    END       

   SELECT TOP 1 @c_Storerkey = Storerkey,
                    @c_Facility = Facility
       FROM ORDERS (NOLOCK) 
       WHERE Loadkey = @c_Loadkey       

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

     --CS03 START
       --INSERT INTO TRACEINFO (TraceName, Step1, Step2, Step3,step4,step5,col1)      
       --VALUES( 'isp_batching_task_pickslip', @c_OrderCount, @c_TaskBatchNo, @c_Pickzone, @c_Mode ,@c_ReGen,@c_updatepick)

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
            WHERE LP.Loadkey = @c_loadkey

            IF ISNULL(@c_LPUDF10,'') = ''
            BEGIN

                UPDATE Loadplan WITH (ROWLOCK)
                SET Userdefine10 = UPPER(@c_updatepick) 
                  , EditWho    = SUSER_SNAME()
                  , EditDate   = GETDATE()
                    WHERE Loadplan.loadkey = @c_loadkey
                    
                SELECT @n_err = @@ERROR
                
                IF @n_err <> 0 
                BEGIN
                  SELECT @n_Continue = 3  
                  SELECT @n_Err = 63210  
                  SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to Update Loadplan (isp_batching_task_pickslip)' 
                  GOTO Quit
                END
            END 
        END     
   END
    --CS03 END
    
    IF @c_ReportType = '0'
    BEGIN
      
       IF @c_ReGen = 'Y'
          SET @c_CallSource = 'RPTREGEN'
       ELSE
          SET @c_CallSource = 'RPT'   

       WHILE @@TRANCOUNT > 0
         COMMIT
      
       BEGIN TRAN  

      --(Wan02) - START
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
      --(Wan02) - END
           
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
           CASE WHEN ISNULL(CL2.Code,'') <> '' THEN 'Y' ELSE 'N' END AS ShowStyleSize,  --NJOW03
           ISNULL(SKU.Style,'') AS Style,  --NJOW03
           ISNULL(SKU.Size,'') AS Size --NJOW03
           --,'' AS Altsku    --,RIGHT(RTRIM(SKU.AltSKU),4) AS Altsku   --CS01   --(Wan01)
         , AltSku = CASE WHEN @c_ReportType = '1' THEN SKU.AltSKU ELSE '' END  --(Wan01)
         , CASE WHEN ISNULL(CL3.Code,'') <> '' THEN 'Y' ELSE 'N' END AS Showloadkeybarcode  --CS03
         , ISNULL(CL4.Short,'N') AS ShowCurrentDateTime  --WL01
         , ISNULL(CL6.Short,'N') AS ShowVAS   --WL02
         , CASE WHEN ISNULL(CL6.Short,'N') = 'N' THEN '' ELSE (SELECT MAX(ISNULL(ORDERINFO.ORDERINFO01,'')) + MAX(ISNULL(ORDERINFO.ORDERINFO02,'')) 
                                                               FROM ORDERINFO (NOLOCK) WHERE ORDERINFO.Orderkey = PD.Orderkey) END AS VAS   --WL02
         , CASE WHEN ISNULL(CL6.Short,'N') = 'N' THEN '' ELSE (SELECT MAX(ISNULL(Orders.Userdefine10,'')) FROM Orders (NOLOCK) WHERE Orders.Orderkey = PD.Orderkey) END AS Userdefine10   --WL02
         , ISNULL(CL5.Short,'N') AS ShowSalesman   --WL03
         , CASE WHEN ISNULL(CL5.Short,'N') = 'N' THEN '' ELSE (SELECT MAX(ISNULL(Orders.Salesman,'')) FROM Orders (NOLOCK) WHERE Orders.Orderkey = PD.Orderkey) END AS Salesman   --WL03
         , ISNULL(CL7.Short,'N') AS ShowCourier   --WL04
         , CASE WHEN ISNULL(CL7.Short,'N') = 'N' THEN '' ELSE (SELECT MAX(ISNULL(Orders.Shipperkey,'')) FROM Orders (NOLOCK) WHERE Orders.Orderkey = PD.Orderkey) END AS Shipperkey   --WL04
    INTO #TMP_TASK
    FROM LOADPLANDETAIL LP (NOLOCK)
    JOIN PICKDETAIL PD (NOLOCK) ON LP.orderkey = PD.OrderKey
    JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
    JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey 
    JOIN LOC L (NOLOCK) ON PD.Loc = L.Loc
    JOIN PACKTASK PT (NOLOCK) ON PD.Orderkey = PT.Orderkey
    LEFT JOIN CODELKUP CL ON RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) = CL.Code AND CL.Listname = 'BATCHMODE' 
    LEFT JOIN Codelkup CL2 (NOLOCK) ON (PD.Storerkey = CL2.Storerkey AND CL2.Code = 'SHOWSTYLESIZE' 
                                              AND CL2.Listname = 'REPORTCFG' AND CL2.Long = 'r_dw_batching_task_pickslip' AND ISNULL(CL2.Short,'') <> 'N')  --NJOW03
    LEFT JOIN Codelkup CL3 (NOLOCK) ON (PD.Storerkey = CL3.Storerkey AND CL3.Code = 'SHOWLOADKEYBARCODE' 
                                              AND CL3.Listname = 'REPORTCFG' AND CL3.Long = 'r_dw_batching_task_pickslip' AND ISNULL(CL3.Short,'') <> 'N')  --CS02
    LEFT JOIN Codelkup CL4 (NOLOCK) ON (PD.Storerkey = CL4.Storerkey AND CL4.Code = 'ShowCurrentDateTime' 
                                              AND CL4.Listname = 'REPORTCFG' AND CL4.Long = 'r_dw_batching_task_pickslip' AND ISNULL(CL4.Short,'') <> 'N')  --WL01
    LEFT JOIN Codelkup CL5 (NOLOCK) ON (PD.Storerkey = CL5.Storerkey AND CL5.Code = 'ShowSalesman' 
                                              AND CL5.Listname = 'REPORTCFG' AND CL5.Long = 'r_dw_batching_task_pickslip' AND ISNULL(CL5.Short,'') <> 'N')  --WL03
    LEFT JOIN Codelkup CL6 (NOLOCK) ON (PD.Storerkey = CL6.Storerkey AND CL6.Code = 'ShowVAS' 
                                              AND CL6.Listname = 'REPORTCFG' AND CL6.Long = 'r_dw_batching_task_pickslip' AND ISNULL(CL6.Short,'') <> 'N')  --WL02
    LEFT JOIN Codelkup CL7 (NOLOCK) ON (PD.Storerkey = CL7.Storerkey AND CL7.Code = 'ShowCourier' 
                                              AND CL7.Listname = 'REPORTCFG' AND CL7.Long = 'r_dw_batching_task_pickslip' AND ISNULL(CL7.Short,'') <> 'N')  --WL04
    WHERE LP.Loadkey = @c_Loadkey
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
             CASE WHEN ISNULL(CL2.Code,'') <> '' THEN 'Y' ELSE 'N' END,  --NJOW03         
             ISNULL(SKU.Style,''),  --NJOW03
             ISNULL(SKU.Size,'') --NJOW03
            -- ,RIGHT(RTRIM(SKU.AltSKU),4)   --CS01
          ,  CASE WHEN @c_ReportType = '1' THEN SKU.AltSKU ELSE '' END  --(Wan01)
          ,  CASE WHEN ISNULL(CL3.Code,'') <> '' THEN 'Y' ELSE 'N' END   --CS03
          ,  ISNULL(CL4.Short,'N')  --WL01
          ,  ISNULL(CL6.Short,'N')  --WL02
          ,  ISNULL(CL5.Short,'N')  --WL03
          ,  ISNULL(CL7.Short,'N')  --WL04
                              
    IF @c_ReportType = '0'
    BEGIN
       SELECT DISTINCT TaskBatchNo, Mode, @c_Loadkey, @c_OrderCount, @c_PickZone,altsku
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
              CASE WHEN Mode = '5' THEN '' ELSE PickZone END AS PickZone,
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
              ShowStyleSize --NJOW03 
            , Altsku             --CS01    
            , Showloadkeybarcode --CS02    
            , ShowCurrentDateTime  --WL01  
            , ShowVAS       --WL02
            , VAS           --WL02
            , Userdefine10  --WL02
            , ShowSalesman  --WL03
            , Salesman      --WL03
            , ShowCourier   --WL04
            , Shipperkey    --WL04
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
                 CASE WHEN ShowStyleSize = 'Y' THEN --NJOW03
                      RTRIM(Style) + SPACE(@n_StyleMaxLen-LEN(Style)) + ' ' + RTRIM(Size)
                 ELSE
                     Descr
                 END,
                 Casecnt,
                 ShowStyleSize --NJOW03
                , Altsku             --CS01 
                , Showloadkeybarcode --CS02
                , ShowCurrentDateTime  --WL01  
                , ShowVAS       --WL02
                , VAS           --WL02
                , Userdefine10  --WL02
                , ShowSalesman  --WL03
                , Salesman      --WL03
                , ShowCourier   --WL04
                , Shipperkey    --WL04
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
             , Altsku             --CS01 
             , Showloadkeybarcode --CS02     
             , ShowCurrentDateTime  --WL01   
             , ShowVAS       --WL02
             , VAS           --WL02
             , Userdefine10  --WL02
             , ShowSalesman  --WL03
             , Salesman      --WL03
             , ShowCourier   --WL04
             , Shipperkey    --WL04
        FROM #TMP_TASK     
        GROUP BY TaskBatchNo,
                 Notes, 
                 Loadkey, 
                 PickZone,
                 ModeDesc,
                 Mode
                , Altsku             --CS01  
                , Showloadkeybarcode --CS02
                , ShowCurrentDateTime  --WL01  
                , ShowVAS       --WL02
                , VAS           --WL02
                , Userdefine10  --WL02
                , ShowSalesman  --WL03
                , Salesman      --WL03
                , ShowCourier   --WL04
                , Shipperkey    --WL04
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
            , Altsku             --CS01  
            , Showloadkeybarcode --CS02
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
              , Altsku             --CS01   
              , Showloadkeybarcode --CS02     
       ORDER BY T.LogicalLocation, T.Loc, T.Sku       
       
       DECLARE Cur_SplitTask CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
          SELECT Orderkey, Sku, Loc, Qty,
                 TaskBatchNo, LogicalLocation, SkuBarcode, Descr, OrderQty, LogicalName, altsku, Showloadkeybarcode  --NJOW04                 
          FROM #TMP_RESULT
          WHERE Qty > 1           
          ORDER BY Sku, Orderkey
                     
       OPEN Cur_SplitTask
        FETCH NEXT FROM Cur_SplitTask INTO @c_Orderkey, @c_Sku, @c_Loc, @n_Qty
                                          ,@c_TaskBatchNo, @c_LogicalLocation, @c_SkuBarcode, @c_Descr, @n_OrderQty, @c_LogicalName, @c_altsku, @c_Showloadkeybarcode  --NJOW04
        
        WHILE @@FETCH_STATUS <> -1 
         BEGIN
             WHILE (@n_Qty - 1) > 0
             BEGIN
                 INSERT INTO #TMP_RESULT (TaskBatchNo, Loc, LogicalLocation, Sku, SkuBarcode, Descr, Orderkey, OrderQty, LogicalName, Qty,altsku,Showloadkeybarcode)--CS01 --CS02
                              VALUES (@c_TaskBatchNo, @c_Loc, @c_LogicalLocation, @c_Sku, @c_SkuBarcode, @c_Descr, @c_Orderkey, @n_OrderQty, @c_LogicalName, 1, @c_altsku, @c_Showloadkeybarcode)  --NJOW04
                 /*
                    SELECT TaskBatchNo, Loc, LogicalLocation, Sku, SkuBarcode, Descr, Orderkey, OrderQty, LogicalName, 1,altsku,Showloadkeybarcode  --CS02     --CS01  
                    FROM #TMP_RESULT 
                    WHERE Orderkey = @c_Orderkey
                    AND Sku = @c_Sku
                    AND Loc = @c_Loc
                    AND Qty > 1
                 */                
                 
                 SET @n_Qty = @n_Qty - 1                
             END
             
            FETCH NEXT FROM Cur_SplitTask INTO @c_Orderkey, @c_Sku, @c_Loc, @n_Qty
                                              ,@c_TaskBatchNo, @c_LogicalLocation, @c_SkuBarcode, @c_Descr, @n_OrderQty, @c_LogicalName, @c_altsku, @c_Showloadkeybarcode  --NJOW04
            
         END
         CLOSE Cur_SplitTask
        DEALLOCATE Cur_SplitTask                    
        
        SELECT TaskBatchNo, Loc, LogicalLocation, Sku, SkuBarcode, Descr, Orderkey, OrderQty, LogicalName,altsku,Showloadkeybarcode --CS02  
        FROM #TMP_RESULT
        ORDER BY LogicalLocation, Loc, Sku     
    END                  

    IF @c_ReportType = '4'
    BEGIN
       SELECT T.Pickzone,
              SUM(T.Qty) AS TotalQty,
              COUNT(DISTINCT T.Sku) AS TotalSku,
              MAX(ShowCourier)   --WL04
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
            , RIGHT(RTRIM(S.AltSKU),4) as Altsku        --CS01
            , Showloadkeybarcode --CS02
            , ShowCurrentDateTime  --WL01 
            , ShowVAS       --WL02
            , VAS           --WL02
            , Userdefine10  --WL02 
            , ShowSalesman  --WL03
            , Salesman      --WL03
            , ShowCourier   --WL04
            , Shipperkey    --WL04
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
              , RIGHT(RTRIM(S.AltSKU),4)--,Altsku        --CS01
              , Showloadkeybarcode --CS02
              , ShowCurrentDateTime  --WL01  
              , ShowVAS       --WL02
              , VAS           --WL02
              , Userdefine10  --WL02
              , ShowSalesman  --WL03
              , Salesman      --WL03
              , ShowCourier   --WL04
              , Shipperkey    --WL04
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