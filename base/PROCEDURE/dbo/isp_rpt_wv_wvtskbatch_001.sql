SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_RPT_WV_WVTSKBATCH_001                          */
/* Creation Date: 12-Sep-2022                                           */
/* Copyright: LF                                                        */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-20707 - CN LOreal Batching Task Pickslip Summary Report */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage: RPT_WV_WVTSKBATCH_001                                         */
/*        Copy from isp_batching_task_pickslip and convert for Logi Rpt */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver.  Purposes                                  */
/* 12-Sep-2022 WLChooi  1.0   DevOps Combine Scipt                      */
/************************************************************************/

CREATE   PROC [dbo].[isp_RPT_WV_WVTSKBATCH_001] (
            @c_Wavekey        NVARCHAR(10)
           ,@c_OrderCount     NVARCHAR(10) = '9999'
           ,@c_Pickzone       NVARCHAR(4000) = ''
           ,@c_Mode           NVARCHAR(10) = ''  -- 1=Multi-S 4=Multi-M 5=BIG 9=Single 
           ,@c_ReGen          NVARCHAR(10) = 'N' --Regnerate flag Y/N           -- 5=Sub report of Multi S & M(Conso Pick when MultiConsoTaskPick=1)                                             
           ,@c_updatepick     NCHAR(5) = 'N'
           ,@c_UOM            NVARCHAR(500) = ''  
           ,@c_rptprocess     NVARCHAR(4000) = ''  
           ,@c_TaskBatchNo    NVARCHAR(10) = ''
           ,@c_ReportType     NVARCHAR(10) = '0' -- 0=Main   1=Single & BIG   2=Multi S & M   3=Sub report of Multi S & M(pick detail)  4=Sub report of Multi S & M(zone summary) 
           ,@c_PreGenRptData  NVARCHAR(10) = 'N'
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
          ,@c_ZoneList            NVARCHAR(4000)  
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
          
   DECLARE @c_LogicalLocation    NVARCHAR(18)
          ,@c_SkuBarcode         NVARCHAR(22) 
          ,@c_Descr              NVARCHAR(60)
          ,@n_OrderQty           INT
          ,@c_LogicalName        NVARCHAR(10)
          ,@c_altsku             NVARCHAR(20)
          ,@c_Showloadkeybarcode NVARCHAR(10)
   
          ,@c_PickByVP           NVARCHAR(30)             
          ,@c_LPUDF10            NVARCHAR(20)
          ,@c_Loadkey            NVARCHAR(10)
          ,@n_RowNo              INT
          ,@c_Detail             NVARCHAR(MAX)

   CREATE TABLE #TMP_RESULT (
      RowNo              INT NOT NULL IDENTITY(1,1) PRIMARY KEY
    , TaskBatchNo        NVARCHAR(50)
    , Loc                NVARCHAR(50)
    , LogicalLocation    NVARCHAR(50)
    , Sku                NVARCHAR(50)
    , Descr              NVARCHAR(50)
    , Orderkey           NVARCHAR(50)
    , OrderQty           NVARCHAR(50)
    , LogicalName        NVARCHAR(50)
    , Qty                INT
    , AltSKU             NVARCHAR(50)
    , ShowWavekeyBarcode NVARCHAR(50)
   )

   DECLARE @TMP_DETAIL AS TABLE(ID INT NOT NULL IDENTITY(1,1) PRIMARY KEY, Detail NVARCHAR(MAX))

   SELECT @b_Success = 1, @n_Err = 0, @c_Errmsg = '', @c_ZoneList = '', @n_StartTCnt = @@TRANCOUNT, @n_Continue = 1  
   
   SELECT @n_OrderCount = CONVERT(INT, @c_OrderCount)
   
   IF @c_PreGenRptData = 'Y' SET @c_PreGenRptData = 'Y' ELSE SET @c_PreGenRptData = 'N'
   IF ISNULL(@c_ReportType,'') = '' SET @c_ReportType =  '0'

   IF ISNULL(@c_PickZone,'') = ''
      SET @c_PickZone = ''
   
   IF ISNULL(@c_TaskBatchNo,'') = ''
      SET @c_TaskBatchNo = ''

   IF @c_Mode NOT IN('1','4','5','9')
   BEGIN 
      SELECT @n_Continue = 3  
      SELECT @n_Err = 63200  
      SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Invalid Mode. The value must be 1,4,5,9 (isp_RPT_WV_WVTSKBATCH_001)'
      GOTO Quit
   END
      
   IF @c_PickZone = 'ALL'
   BEGIN   
      SELECT @c_ZoneList = STUFF((SELECT ',' + RTRIM(Loc.PickZone)     
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN ORDERS O (NOLOCK) ON O.Orderkey = WD.Orderkey     
      JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey     
      JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
      WHERE WD.WaveKey = @c_Wavekey
      GROUP BY LOC.PickZone
      ORDER BY LOC.PickZone FOR XML PATH('')),1,1,'' ) + ','   
           
      IF ISNULL(@c_ZoneList,'') <> ''
      BEGIN
         SET @c_ZoneList = LEFT(@c_ZoneList, LEN(RTRIM(@c_ZoneList)) - 1)
         SET @c_PickZone = @c_ZoneList
      END
   END       

   SELECT TOP 1 @c_Storerkey = Storerkey,
                @c_Facility = Facility
   FROM WAVEDETAIL (NOLOCK)
   JOIN ORDERS (NOLOCK) ON WAVEDETAIL.OrderKey = ORDERS.OrderKey
   WHERE WAVEDETAIL.WaveKey = @c_Wavekey       

   IF @c_ReportType IN ('2','3','5')
   BEGIN
             
      SET @c_MultiConsoTaskPick = ''
      EXECUTE nspGetRight 
      @c_facility,  
      @c_StorerKey,              
      '', --@c_Sku                    
      'MultiConsoTaskPick', -- Configkey
      @b_success            OUTPUT,
      @c_MultiConsoTaskPick OUTPUT,
      @n_err                OUTPUT,
      @c_errmsg             OUTPUT  
      
      SET @c_MultiConsoTaskPick = TRIM(@c_MultiConsoTaskPick)
   END         

   IF UPPER(@c_updatepick) = 'VP'
   BEGIN
      SET @c_PickByVP = ''
      SET @c_LPUDF10 = ''
      
      EXECUTE nspGetRight 
      @c_facility,  
      @c_StorerKey,              
      '', --@c_Sku                    
      'PickByVoicePicking', -- Configkey
      @b_success            OUTPUT,
      @c_PickByVP           OUTPUT,
      @n_err                OUTPUT,
      @c_errmsg             OUTPUT             
          
      IF ISNULL(@c_PickByVP,'') = '1' AND @c_PreGenRptData = 'Y'
      BEGIN
         DECLARE CUR_VP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT LPD.Loadkey
         FROM LOADPLANDETAIL LPD (NOLOCK)
         JOIN ORDERS OH (NOLOCK) ON LPD.OrderKey = OH.OrderKey
         JOIN WAVEDETAIL WD (NOLOCK) ON WD.OrderKey = OH.OrderKey
         WHERE WD.WaveKey = @c_Wavekey

         OPEN CUR_VP

         FETCH NEXT FROM CUR_VP INTO @c_Loadkey

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SET @c_LPUDF10 = ''

            SELECT @c_LPUDF10 = LP.Userdefine10
            FROM LOADPLAN LP WITH (NOLOCK)
            WHERE LP.Loadkey = @c_Loadkey
         
            IF ISNULL(@c_LPUDF10,'') = ''
            BEGIN
               UPDATE Loadplan WITH (ROWLOCK)
               SET Userdefine10 = UPPER(@c_updatepick) 
                 , EditWho    = SUSER_SNAME()
                 , EditDate   = GETDATE()
               WHERE Loadplan.loadkey = @c_Loadkey
                 
               SELECT @n_err = @@ERROR
             
               IF @n_err <> 0 
               BEGIN
                  SELECT @n_Continue = 3  
                  SELECT @n_Err = 63210  
                  SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to Update Loadplan (isp_RPT_WV_WVTSKBATCH_001)' 
                  GOTO Quit
               END
            END 
            FETCH NEXT FROM CUR_VP INTO @c_Loadkey
         END
         CLOSE CUR_VP
         DEALLOCATE CUR_VP
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
      
      IF @c_PreGenRptData = 'Y'
      BEGIN
         BEGIN TRAN  
         
         EXEC dbo.ispOrderBatching @c_LoadKey      = N''                  
                                 , @n_OrderCount   = @n_OrderCount                
                                 , @c_PickZones    = @c_PickZone
                                 , @c_Mode         = @c_Mode                     
                                 , @b_Success      = @b_Success   OUTPUT    
                                 , @n_Err          = @n_Err       OUTPUT            
                                 , @c_ErrMsg       = @c_ErrMsg    OUTPUT      
                                 , @c_CallSource   = @c_CallSource            
                                 , @c_WaveKey      = @c_Wavekey                  
                                 , @c_UOM          = @c_UOM                      
                                 , @c_updatepick   = @c_updatepick            
                                 , @c_rptprocess   = @c_rptprocess             
              
         IF @b_Success = 0
         BEGIN
            ROLLBACK
                      
            SELECT @n_Continue = 3 
            GOTO Quit
         END  
      END
       
      WHILE @@TRANCOUNT > 0
         COMMIT
   END              

   IF @c_PreGenRptData = 'N'
   BEGIN
      SELECT PT.TaskBatchNo, 
             PD.Orderkey,
             PD.Notes, 
             WD.WaveKey, 
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
           , AltSku = CASE WHEN @c_ReportType = '1' THEN SKU.AltSKU ELSE '' END 
           , CASE WHEN ISNULL(CL3.Code,'') <> '' THEN 'Y' ELSE 'N' END AS ShowWavekeyBarcode 
           , ISNULL(CL4.Short,'N') AS ShowCurrentDateTime
           , ISNULL(CL6.Short,'N') AS ShowVAS
           , CASE WHEN ISNULL(CL6.Short,'N') = 'N' THEN '' ELSE (SELECT MAX(ISNULL(ORDERINFO.ORDERINFO01,'')) + MAX(ISNULL(ORDERINFO.ORDERINFO02,'')) 
                                                                 FROM ORDERINFO (NOLOCK) WHERE ORDERINFO.Orderkey = PD.Orderkey) END AS VAS
           , CASE WHEN ISNULL(CL6.Short,'N') = 'N' THEN '' ELSE (SELECT MAX(ISNULL(Orders.Userdefine10,'')) FROM Orders (NOLOCK) WHERE Orders.Orderkey = PD.Orderkey) END AS Userdefine10
           , ISNULL(CL5.Short,'N') AS ShowSalesman
           , CASE WHEN ISNULL(CL5.Short,'N') = 'N' THEN '' ELSE (SELECT MAX(ISNULL(Orders.Salesman,'')) FROM Orders (NOLOCK) WHERE Orders.Orderkey = PD.Orderkey) END AS Salesman
           , ISNULL(CL7.Short,'N') AS ShowCourier 
           , CASE WHEN ISNULL(CL7.Short,'N') = 'N' THEN '' ELSE (SELECT MAX(ISNULL(Orders.Shipperkey,'')) FROM Orders (NOLOCK) WHERE Orders.Orderkey = PD.Orderkey) END AS Shipperkey
      INTO #TMP_TASK
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN PICKDETAIL PD (NOLOCK) ON WD.orderkey = PD.OrderKey
      JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
      JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey 
      JOIN LOC L (NOLOCK) ON PD.Loc = L.Loc
      JOIN PACKTASK PT (NOLOCK) ON PD.Orderkey = PT.Orderkey
      LEFT JOIN CODELKUP CL ON RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) = CL.Code AND CL.Listname = 'BATCHMODE' 
      LEFT JOIN Codelkup CL2 (NOLOCK) ON (PD.Storerkey = CL2.Storerkey AND CL2.Code = 'SHOWSTYLESIZE' 
                                                AND CL2.Listname = 'REPORTCFG' AND CL2.Long = 'RPT_WV_WVTSKBATCH_001' AND ISNULL(CL2.Short,'') <> 'N')
      LEFT JOIN Codelkup CL3 (NOLOCK) ON (PD.Storerkey = CL3.Storerkey AND CL3.Code = 'ShowWavekeyBarcode' 
                                                AND CL3.Listname = 'REPORTCFG' AND CL3.Long = 'RPT_WV_WVTSKBATCH_001' AND ISNULL(CL3.Short,'') <> 'N')
      LEFT JOIN Codelkup CL4 (NOLOCK) ON (PD.Storerkey = CL4.Storerkey AND CL4.Code = 'ShowCurrentDateTime' 
                                                AND CL4.Listname = 'REPORTCFG' AND CL4.Long = 'RPT_WV_WVTSKBATCH_001' AND ISNULL(CL4.Short,'') <> 'N')
      LEFT JOIN Codelkup CL5 (NOLOCK) ON (PD.Storerkey = CL5.Storerkey AND CL5.Code = 'ShowSalesman' 
                                                AND CL5.Listname = 'REPORTCFG' AND CL5.Long = 'RPT_WV_WVTSKBATCH_001' AND ISNULL(CL5.Short,'') <> 'N')
      LEFT JOIN Codelkup CL6 (NOLOCK) ON (PD.Storerkey = CL6.Storerkey AND CL6.Code = 'ShowVAS' 
                                                AND CL6.Listname = 'REPORTCFG' AND CL6.Long = 'RPT_WV_WVTSKBATCH_001' AND ISNULL(CL6.Short,'') <> 'N')
      LEFT JOIN Codelkup CL7 (NOLOCK) ON (PD.Storerkey = CL7.Storerkey AND CL7.Code = 'ShowCourier' 
                                                AND CL7.Listname = 'REPORTCFG' AND CL7.Long = 'RPT_WV_WVTSKBATCH_001' AND ISNULL(CL7.Short,'') <> 'N')
      WHERE WD.WaveKey = @c_Wavekey
      AND PT.TaskBatchNo = CASE WHEN @c_TaskBatchNo <> '' THEN @c_TaskBatchNo ELSE PT.TaskBatchNo END
      AND L.Pickzone IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_PickZone)) 
      AND RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) = @c_Mode
      AND 1 = CASE WHEN (@c_ReportType = '3' AND @c_MultiConsoTaskPick = '1') OR (@c_ReportType = '5' AND @c_MultiConsoTaskPick <> '1') THEN 2 ELSE 1 END
      GROUP BY PT.TaskBatchNo, 
               PD.Orderkey,
               PD.Notes, 
               WD.WaveKey,
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
            ,  CASE WHEN @c_ReportType = '1' THEN SKU.AltSKU ELSE '' END
            ,  CASE WHEN ISNULL(CL3.Code,'') <> '' THEN 'Y' ELSE 'N' END
            ,  ISNULL(CL4.Short,'N')
            ,  ISNULL(CL6.Short,'N')
            ,  ISNULL(CL5.Short,'N')
            ,  ISNULL(CL7.Short,'N')
   END
                             
   IF @c_ReportType = '0' AND @c_PreGenRptData = 'N'
   BEGIN
      SELECT DISTINCT TaskBatchNo, Mode, @c_Wavekey AS Wavekey
                    , @c_OrderCount AS OrderCount, @c_PickZone AS Pickzone, AltSKU
      FROM #TMP_TASK
      ORDER BY Mode, TaskBatchNo
   END
   
   IF @c_ReportType = '1' AND @c_PreGenRptData = 'N'
   BEGIN      
      SELECT @n_StyleMaxLen = MAX(LEN(Style))
      FROM #TMP_TASK
                  
      IF ISNULL(@n_StyleMaxLen,0) < 15
         SET @n_StyleMaxLen = 15
      
      SELECT TaskBatchNo, 
             Notes, 
             WaveKey, 
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
             END AS Descr,
             Casecnt,
             (SELECT SUM(T.Qty) FROM #TMP_TASK T WHERE T.TaskBatchNo = #TMP_TASK.TaskBatchNo) AS TotalQty,
             (SELECT COUNT(DISTINCT T.SKU) FROM #TMP_TASK T WHERE T.TaskBatchNo = #TMP_TASK.TaskBatchNo) AS TotalSku,
             ShowStyleSize
           , RIGHT(TRIM(Altsku), 4) AS AltSKU        
           , ShowWavekeyBarcode  
           , ShowCurrentDateTime 
           , ShowVAS     
           , TRIM(VAS) AS VAS         
           , TRIM(Userdefine10) AS Userdefine10
           , ShowSalesman
           , Salesman    
           , ShowCourier 
           , Shipperkey 
           , FLOOR(SUM(Qty) / CAST(CaseCnt AS INT)) AS [Case]
           , (SUM(Qty) % CAST(CaseCnt AS INT)) AS LoosePCS
      FROM #TMP_TASK     
      GROUP BY TaskBatchNo,
                Notes, 
                WaveKey, 
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
               , ShowWavekeyBarcode
               , ShowCurrentDateTime
               , ShowVAS     
               , TRIM(VAS)         
               , TRIM(Userdefine10)
               , ShowSalesman
               , Salesman    
               , ShowCourier 
               , Shipperkey  
      ORDER BY TaskBatchNo, LogicalLocation, Loc, Sku
   END
          
   IF @c_ReportType = '2'
   BEGIN
      IF ISNULL(@c_MultiConsoTaskPick,'') <> '1' --if not multi conso pick (discrete)
         AND @c_PreGenRptData = 'Y'
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

      IF @c_PreGenRptData = 'N'
      BEGIN
         SELECT TaskBatchNo, 
                Notes, 
                WaveKey, 
                TRIM(PickZone) AS PickZone,
                ModeDesc,              
                Mode,
                (SELECT SUM(T.Qty) FROM #TMP_TASK T WHERE T.TaskBatchNo = #TMP_TASK.TaskBatchNo) AS TotalQty,
                (SELECT COUNT(DISTINCT T.SKU) FROM #TMP_TASK T WHERE T.TaskBatchNo = #TMP_TASK.TaskBatchNo) AS TotalSku,
                @c_Wavekey AS Wavekey,              
                @c_ordercount AS OrderCount,
                @c_pickzone AS Pickzone,
                @c_MultiConsoTaskPick AS MultiConsoTaskPick 
               , Altsku
               , ShowWavekeyBarcode
               , ShowCurrentDateTime
               , ShowVAS     
               , TRIM(VAS) AS VAS         
               , TRIM(Userdefine10) AS Userdefine10
               , ShowSalesman
               , Salesman    
               , ShowCourier 
               , Shipperkey  
         FROM #TMP_TASK     
         GROUP BY  TaskBatchNo,
                   Notes, 
                   WaveKey, 
                   TRIM(PickZone),
                   ModeDesc,
                   Mode
                  , Altsku             
                  , ShowWavekeyBarcode 
                  , ShowCurrentDateTime  
                  , ShowVAS     
                  , TRIM(VAS)         
                  , TRIM(Userdefine10)
                  , ShowSalesman
                  , Salesman    
                  , ShowCourier 
                  , Shipperkey  
         ORDER BY TaskBatchNo
      END
   END
   
   IF @c_ReportType = '3' AND @c_PreGenRptData = 'N'
   BEGIN
      INSERT INTO #TMP_RESULT
      SELECT T.TaskBatchNo
           , T.Loc
           , T.LogicalLocation            
           , TRIM(T.Sku) AS SKU
           , T.Descr
           , T.Orderkey
           , (SELECT SUM(PD.Qty) FROM PICKDETAIL PD (NOLOCK) WHERE PD.Orderkey = T.Orderkey) AS OrderQty
           , PT.LogicalName
           , SUM(T.Qty) AS Qty
           , Altsku               
           , ShowWavekeyBarcode      
      FROM #TMP_TASK T      
      JOIN PACKTASK PT (NOLOCK) ON T.Orderkey = PT.Orderkey AND T.TaskBatchNo = PT.TaskBatchNo        
      GROUP BY T.TaskBatchNo
             , T.Loc
             , T.LogicalLocation          
             , TRIM(T.Sku)
             , T.Descr
             , T.Orderkey
             , PT.LogicalName 
             , Altsku                
             , ShowWavekeyBarcode      
      ORDER BY T.LogicalLocation, T.Loc, TRIM(T.Sku)     
      
      DECLARE Cur_SplitTask CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT Orderkey, Sku, Loc, Qty,
                TaskBatchNo, LogicalLocation, Descr, OrderQty, LogicalName, altsku, ShowWavekeyBarcode                   
         FROM #TMP_RESULT
         WHERE Qty > 1           
         ORDER BY Sku, Orderkey
                    
      OPEN Cur_SplitTask
      FETCH NEXT FROM Cur_SplitTask INTO @c_Orderkey, @c_Sku, @c_Loc, @n_Qty
                                        ,@c_TaskBatchNo, @c_LogicalLocation, @c_Descr, @n_OrderQty, @c_LogicalName, @c_altsku, @c_Showloadkeybarcode  
       
      WHILE @@FETCH_STATUS <> -1 
      BEGIN
         WHILE (@n_Qty - 1) > 0
         BEGIN
            INSERT INTO #TMP_RESULT (TaskBatchNo, Loc, LogicalLocation, Sku, Descr, Orderkey, OrderQty, LogicalName, Qty,altsku,ShowWavekeyBarcode)
            VALUES (@c_TaskBatchNo, @c_Loc, @c_LogicalLocation, @c_Sku, @c_Descr, @c_Orderkey, @n_OrderQty, @c_LogicalName, 1, @c_altsku, @c_Showloadkeybarcode) 
   
            SET @n_Qty = @n_Qty - 1                
         END
            
         FETCH NEXT FROM Cur_SplitTask INTO @c_Orderkey, @c_Sku, @c_Loc, @n_Qty
                                           ,@c_TaskBatchNo, @c_LogicalLocation, @c_Descr, @n_OrderQty, @c_LogicalName, @c_altsku, @c_Showloadkeybarcode
           
      END
      CLOSE Cur_SplitTask
      DEALLOCATE Cur_SplitTask                    

      WHILE EXISTS (SELECT 1 FROM #TMP_RESULT TR)
      BEGIN
         SET @c_Detail = ''

         DECLARE CUR_SPLIT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT TOP 4 RowNo, TaskBatchNo, Loc, LogicalLocation, Sku, Descr, Orderkey, OrderQty, LogicalName, AltSku, ShowWavekeyBarcode  
         FROM #TMP_RESULT
         ORDER BY LogicalLocation, Loc, Sku 
         
         OPEN CUR_SPLIT
         
         FETCH NEXT FROM CUR_SPLIT INTO @n_RowNo, @c_TaskBatchNo, @c_Loc, @c_LogicalLocation, @c_Sku, @c_Descr, @c_Orderkey
                                      , @n_OrderQty, @c_LogicalName, @c_AltSku, @c_Showloadkeybarcode
         
         WHILE @@FETCH_STATUS <> -1
         BEGIN

            SELECT @c_Detail = @c_Detail 
                             + @c_TaskBatchNo + CHAR(13) + @c_Loc + CHAR(13) + @c_LogicalLocation + CHAR(13) + @c_Sku + CHAR(13) + @c_Descr + CHAR(13) + @c_Orderkey + CHAR(13)
                             + CAST(@n_OrderQty AS NVARCHAR) + CHAR(13) + @c_LogicalName + CHAR(13) + @c_AltSku + CHAR(13) + @c_Showloadkeybarcode + CHAR(13)

            DELETE FROM #TMP_RESULT WHERE RowNo = @n_RowNo

            FETCH NEXT FROM CUR_SPLIT INTO @n_RowNo, @c_TaskBatchNo, @c_Loc, @c_LogicalLocation, @c_Sku, @c_Descr, @c_Orderkey
                                         , @n_OrderQty, @c_LogicalName, @c_AltSku, @c_Showloadkeybarcode
         END
         CLOSE CUR_SPLIT
         DEALLOCATE CUR_SPLIT

         INSERT INTO @TMP_DETAIL (Detail)
         SELECT @c_Detail
      END

      ;WITH SplitValues (ID, OriginalValue, SplitValue, Level)
      AS
      (
          SELECT ID, Detail, CAST('' AS NVARCHAR(MAX)), 0 FROM @TMP_DETAIL
          UNION ALL
          SELECT ID
               , SUBSTRING(OriginalValue, CASE WHEN CHARINDEX(CHAR(13), OriginalValue) = 0 THEN LEN(OriginalValue) + 1 ELSE CHARINDEX(CHAR(13), OriginalValue) + 1 END, LEN(OriginalValue))
               , SUBSTRING(OriginalValue, 0, CASE WHEN CHARINDEX(CHAR(13), OriginalValue) = 0 THEN LEN(OriginalValue) + 1 ELSE CHARINDEX(CHAR(13), OriginalValue) END)
               , Level + 1
          FROM    SplitValues
          WHERE   LEN(SplitValues.OriginalValue) > 0
      )
      SELECT [1]  AS [TaskBatchNo_1], [2]  AS [Loc_1], [3]  AS [LogicalLocation_1], [4]  AS [Sku_1], [5]  AS [Descr_1], [6]  AS [Orderkey_1], [7]  AS [OrderQty_1], [8]  AS [LogicalName_1], [9]  AS [AltSku_1], [10] AS [Showloadkeybarcode_1]
           , [11] AS [TaskBatchNo_2], [12] AS [Loc_2], [13] AS [LogicalLocation_2], [14] AS [Sku_2], [15] AS [Descr_2], [16] AS [Orderkey_2], [17] AS [OrderQty_2], [18] AS [LogicalName_2], [19] AS [AltSku_2], [20] AS [Showloadkeybarcode_2]
           , [21] AS [TaskBatchNo_3], [22] AS [Loc_3], [23] AS [LogicalLocation_3], [24] AS [Sku_3], [25] AS [Descr_3], [26] AS [Orderkey_3], [27] AS [OrderQty_3], [28] AS [LogicalName_3], [29] AS [AltSku_3], [30] AS [Showloadkeybarcode_3]
           , [31] AS [TaskBatchNo_4], [32] AS [Loc_4], [33] AS [LogicalLocation_4], [34] AS [Sku_4], [35] AS [Descr_4], [36] AS [Orderkey_4], [37] AS [OrderQty_4], [38] AS [LogicalName_4], [39] AS [AltSku_4], [40] AS [Showloadkeybarcode_4]
      FROM    (
          SELECT ID, Level, SplitValue
          FROM   SplitValues
          WHERE  Level > 0
          ) AS p
      PIVOT (MAX(SplitValue) FOR Level IN ([1] , [2] , [3] , [4] , [5] , [6] , [7] , [8] , [9] , [10]
                                         , [11], [12], [13], [14], [15], [16], [17], [18], [19], [20]
                                         , [21], [22], [23], [24], [25], [26], [27], [28], [29], [30]
                                         , [31], [32], [33], [34], [35], [36], [37], [38], [39], [40]
                                         )) AS PVT ORDER BY ID OPTION (MAXRECURSION 0)

   END                  

   IF @c_ReportType = '4' AND @c_PreGenRptData = 'N'
   BEGIN
      SELECT T.Pickzone,
             SUM(T.Qty) AS TotalQty,
             COUNT(DISTINCT T.Sku) AS TotalSku,
             MAX(ShowCourier) AS ShowCourier
      FROM #TMP_TASK T      
      GROUP BY T.Pickzone
      ORDER BY T.PickZone
   END               
   
   IF @c_ReportType = '5' AND @c_PreGenRptData = 'N'
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
             END AS Descr,
             TTS.Casecnt,
             ShowStyleSize 
           , RIGHT(RTRIM(S.AltSKU),4) as Altsku 
           , ShowWavekeyBarcode 
           , ShowCurrentDateTime   
           , ShowVAS     
           , VAS         
           , Userdefine10 
           , ShowSalesman
           , Salesman    
           , ShowCourier 
           , Shipperkey  
           , FLOOR(SUM(TTS.Qty) / CAST(TTS.CaseCnt AS INT)) AS [Case]
           , (SUM(TTS.Qty) % CAST(TTS.CaseCnt AS INT)) AS LoosePCS
      FROM #TMP_TASK TTS
      JOIN SKU S WITH (NOLOCK) ON S.sku=TTS.sku AND s.storerkey=@c_Storerkey         
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
             , ShowWavekeyBarcode
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
   IF CURSOR_STATUS('LOCAL', 'CUR_VP') IN ('0','1')
   BEGIN
      CLOSE CUR_VP
      DEALLOCATE CUR_VP
   END

   IF OBJECT_ID('tempdb..#TMP_TASK')  IS NOT NULL
      DROP TABLE #TMP_TASK

   IF OBJECT_ID('tempdb..#TMP_RESULT')  IS NOT NULL
      DROP TABLE #TMP_RESULT
   
   IF CURSOR_STATUS('LOCAL', 'CUR_SPLIT') IN (0,1)
   BEGIN
      CLOSE CUR_SPLIT
      DEALLOCATE CUR_SPLIT
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_VP') IN (0,1)
   BEGIN
      CLOSE CUR_VP
      DEALLOCATE CUR_VP
   END

   IF CURSOR_STATUS('LOCAL', 'Cur_SplitTask') IN (0,1)
   BEGIN
      CLOSE Cur_SplitTask
      DEALLOCATE Cur_SplitTask
   END

   IF CURSOR_STATUS('LOCAL', 'Cur_Task') IN (0,1)
   BEGIN
      CLOSE Cur_Task
      DEALLOCATE Cur_Task
   END

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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_RPT_WV_WVTSKBATCH_001'  
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