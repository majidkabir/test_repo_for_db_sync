SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/        
/* Stored Procedure: isp_RPT_WV_WAVELPDET_001                           */        
/* CreatiON Date: 07-JUL-2023                                           */    
/* Copyright: Maersk                                                    */    
/* Written by: WZPang                                                   */    
/*                                                                      */    
/* Purpose: WMS-22858 (TW)                                              */      
/*                                                                      */        
/* Called By: RPT_WV_WAVELPDET_001            									*/        
/*                                                                      */        
/* PVCS VersiON: 1.0                                                    */        
/*                                                                      */        
/* VersiON: 7.0                                                         */        
/*                                                                      */        
/* Data ModificatiONs:                                                  */        
/*                                                                      */        
/* Updates:                                                             */        
/* Date         Author   Ver  Purposes                                  */
/* 07-JUL-2023  WZPang   1.0  DevOps Combine Script                     */
/* 19-SEP-2023  WZPang   1.1  Add Sorting (ORDER BY LEFT(SKU, 8))       */
/************************************************************************/        
CREATE   PROC [dbo].[isp_RPT_WV_WAVELPDET_001] (
      @c_Wavekey        NVARCHAR(10),  
      @c_PreGenRptData  NVARCHAR(10) = ''
)        
 AS        
 BEGIN        
            
   SET NOCOUNT ON        
   SET ANSI_NULLS ON        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
   SET ANSI_WARNINGS ON        

   DECLARE @c_PickheaderKey  NVARCHAR(10)  
         , @c_PickSlipNo     NVARCHAR(10)  
         , @c_PrintedFlag    NVARCHAR(1)  
         , @n_continue       INT  
         , @c_errmsg         NVARCHAR(255)  
         , @b_success        INT  
         , @n_err            INT  
         , @c_Facility       NVARCHAR(5)  
         , @c_orderkey       NVARCHAR(10)  
         , @c_Externorderkey NVARCHAR(30)  
         , @c_Consigneekey   NVARCHAR(15)  
         , @c_BillToKey      NVARCHAR(15)  
         , @c_Company        NVARCHAR(45)  
         , @c_Addr1          NVARCHAR(45)  
         , @c_Addr2          NVARCHAR(45)  
         , @c_Addr3          NVARCHAR(45)  
         , @c_PostCode       NVARCHAR(15)  
         , @c_Route          NVARCHAR(10)  
         , @c_Route_Desc     NVARCHAR(60) -- RouteMaster.Desc  
         , @c_TrfRoom        NVARCHAR(5)  -- LoadPlan.TrfRoom  
         , @c_Carrierkey     NVARCHAR(60)  
         , @c_VehicleNo      NVARCHAR(10)  
         , @c_DeliveryNote   NVARCHAR(10)  
         , @d_DeliveryDate   DATETIME  
         , @c_labelPrice     NVARCHAR(5)  
         , @c_Notes1         NVARCHAR(60)  
         , @c_Notes2         NVARCHAR(60)  
         , @c_StorerKey      NVARCHAR(15)  
         , @c_sku            NVARCHAR(20)  
         , @c_SkuDesc        NVARCHAR(60)  
         , @c_UOM            NVARCHAR(10)  
         , @c_loc            NVARCHAR(10)  
         , @c_ID             NVARCHAR(18)  
         , @n_qty            INT  
         , @c_Logicalloc     NVARCHAR(18)  
         , @c_firsttime      NVARCHAR(1)  
         , @n_MaxPerPage     INT = 28
         , @n_CountSku       INT
         , @n_TotalPcs       INT
         , @n_TotalSku       INT
         , @n_Pcs            INT

  
   DECLARE @c_RetailSKU NVARCHAR(40)  
         , @c_Color     NVARCHAR(10)  
         , @c_Size      NVARCHAR(5)  
         , @c_Article   NVARCHAR(70)  
  
   DECLARE @n_PS_required   INT  
         , @c_NextNo        NVARCHAR(10)  
         , @c_cdescr        NVARCHAR(120)  
         , @c_ecomflag      NVARCHAR(50)  
         , @c_Loadkey       NVARCHAR(10)  
         , @c_Wavedetailkey NVARCHAR(10)  
         , @c_SUMQty        NVARCHAR(10)
  
   SET @c_RetailSKU = N''  
   SET @c_Color = N''  
   SET @c_Size = N''  
   SET @c_cdescr = N''  

   CREATE TABLE #temp_pick  
   (  
      RowID          INT          NOT NULL IDENTITY(1, 1) PRIMARY KEY  
    , PickSlipNo     NVARCHAR(10) NULL 
    , LoadKey        NVARCHAR(10)
    , OrderKey       NVARCHAR(10)
    , SKU            NVARCHAR(20) 
    , Pcs            INT   
    , Wavekey        NVARCHAR(10)
    , CountSku       INT
    , TotalPcs       INT
    , TotalSku       INT
    , Wavedetailkey  NVARCHAR(10)
   )  

   CREATE TABLE #temp_pick2
   (
      RowID          INT          NOT NULL IDENTITY(1, 1) PRIMARY KEY
    , SKU            NVARCHAR(20) 
    , Pcs            INT   
    , Wavekey        NVARCHAR(10)
    , CountSku       INT
    , TotalPcs       INT
    , TotalSku       INT
    , Loadkey        NVARCHAR(10)
   )

   DECLARE CUR_PICK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT @c_Wavekey AS Wavekey,
         PICKDETAIL.SKU AS Generic,
         COUNT(DISTINCT PICKDETAIL.SKU)   AS CountSku,
         SUM(PICKDETAIL.Qty)     AS Pcs,
         (SELECT SUM(PD.Qty)
         FROM WAVEDETAIL WD (NOLOCK)
         JOIN PICKDETAIL PD (NOLOCK) ON (WD.OrderKey = PD.OrderKey)
         WHERE WD.WaveKey = @c_Wavekey) AS TotalPcs,
         (SELECT COUNT(PD2.SKU)
         FROM WAVEDETAIL WD2 (NOLOCK)
         JOIN PICKDETAIL PD2 (NOLOCK) ON (WD2.OrderKey = PD2.OrderKey)
         WHERE WD2.WaveKey = @c_Wavekey) AS TotalSku,
         LOADPLAN.LoadKey,
         ORDERS.Orderkey,
         WAVEDETAIL.WaveDetailKey
   FROM WAVEDETAIL (NOLOCK)
   JOIN PICKDETAIL WITH (NOLOCK) ON (WAVEDETAIL.OrderKey = PICKDETAIL.OrderKey)  
   JOIN ORDERS WITH (NOLOCK) ON (PICKDETAIL.OrderKey = ORDERS.OrderKey)  
   JOIN LOADPLAN WITH (NOLOCK) ON (ORDERS.LoadKey = LOADPLAN.LoadKey)
   WHERE WAVEDETAIL.WaveKey = @c_Wavekey  
   GROUP BY PICKDETAIL.SKU,
            LOADPLAN.LoadKey,
            ORDERS.Orderkey,
            WAVEDETAIL.WaveDetailKey
  
   OPEN CUR_PICK  
  
   FETCH NEXT FROM CUR_PICK  
   INTO @c_Wavekey
      , @c_Sku
      , @n_CountSku
      , @n_Pcs
      , @n_TotalPcs
      , @n_TotalSku
      , @c_Loadkey
      , @c_Orderkey
      , @c_Wavedetailkey 
      
      
   WHILE (@@FETCH_STATUS <> -1)  
   BEGIN  
      -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 8 - By Order  
      IF EXISTS (  SELECT 1  
                   FROM PICKHEADER (NOLOCK)  
                   WHERE ExternOrderKey = @c_Loadkey AND Zone = '3')  
      BEGIN  
         SET @c_firsttime = N'N'  
         SET @c_PrintedFlag = N'Y'  
      END  
      ELSE  
      BEGIN  
         SET @c_firsttime = N'Y'  
         SET @c_PrintedFlag = N'N'  
      END -- Record Not Exists 
      
      IF @c_PreGenRptData = 'Y'
      BEGIN 
         BEGIN TRAN  
         -- Uses PickType as a Printed Flag  
         UPDATE PICKHEADER WITH (ROWLOCK)  
         SET PickType = '1'  
           , TrafficCop = NULL  
         WHERE ExternOrderKey = @c_Loadkey AND Zone = '3' AND PickType = '0'  
  
         SET @n_err = @@ERROR  
         IF @n_err <> 0  
         BEGIN  
            SET @n_continue = 3  
            IF @@TRANCOUNT >= 1  
            BEGIN  
               ROLLBACK TRAN  
               GOTO FAILURE  
            END  
         END  
         ELSE  
         BEGIN  
            IF @@TRANCOUNT > 0  
            BEGIN  
               COMMIT TRAN  
            END  
            ELSE  
            BEGIN  
               SET @n_continue = 3  
               ROLLBACK TRAN  
               GOTO FAILURE  
            END  
         END  
      END

      SET @c_PickheaderKey = N''  
  
      SELECT @c_PickheaderKey = ISNULL(PickHeaderKey, '')  
      FROM PICKHEADER (NOLOCK)  
      WHERE ExternOrderKey = @c_Loadkey AND OrderKey = @c_orderkey AND Zone = '3'  
  
      INSERT INTO #temp_pick (PickSlipNo, SKU, Pcs, Wavekey, CountSku, TotalPcs, TotalSku, Loadkey, OrderKey)
      VALUES (@c_PickheaderKey, @c_SKU, @n_Pcs, @c_Wavekey, @n_CountSku, @n_TotalPcs, @n_TotalSku, @c_Loadkey, @c_Orderkey)  
  
      FETCH NEXT FROM CUR_PICK  
      INTO @c_Wavekey
      , @c_Sku
      , @n_CountSku
      , @n_Pcs
      , @n_TotalPcs
      , @n_TotalSku
      , @c_Loadkey
      , @c_Orderkey
      , @c_Wavedetailkey 
   END  
   CLOSE CUR_PICK  
   DEALLOCATE CUR_PICK
   
   FAILURE:  

   SELECT @n_PS_required = COUNT(DISTINCT OrderKey)  
   FROM #temp_pick  
   WHERE PickSlipNo IS NULL OR RTRIM(PickSlipNo) = ''  
  
   IF @n_PS_required > 0 --AND @c_PreGenRptData = 'Y'  
   BEGIN  
      EXECUTE nspg_GetKey 'PICKSLIP'  
                        , 9  
                        , @c_NextNo OUTPUT  
                        , @b_success OUTPUT  
                        , @n_err OUTPUT  
                        , @c_errmsg OUTPUT  
                        , 0  
                        , @n_PS_required  
      IF @b_success <> 1  
         GOTO FAILURE  
  
  
      SET @c_orderkey = N''  
      DECLARE CUR_PS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT LoadKey  
           , OrderKey  
      FROM #temp_pick  
      WHERE PickSlipNo IS NULL OR RTRIM(PickSlipNo) = ''  
      GROUP BY LoadKey  
             , OrderKey  
             , Wavedetailkey  
      ORDER BY Wavedetailkey  
  
      OPEN CUR_PS  
  
      FETCH NEXT FROM CUR_PS  
      INTO @c_Loadkey  
         , @c_orderkey  
  
      WHILE (@@FETCH_STATUS <> -1)  
      BEGIN  
         IF @c_orderkey IS NULL OR RTRIM(@c_orderkey) = ''  
         BEGIN  
            BREAK  
         END  
  
         IF NOT EXISTS (  SELECT 1  
                          FROM PICKHEADER (NOLOCK)  
                          WHERE OrderKey = @c_orderkey)  
         BEGIN  
            SET @c_PickheaderKey = N'P' + @c_NextNo  
            SET @c_NextNo = RIGHT('000000000' + CONVERT(NVARCHAR(9), CONVERT(INT, @c_NextNo) + 1), 9)  
  
            BEGIN TRAN  
            INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)  
            VALUES (@c_PickheaderKey, @c_orderkey, @c_Loadkey, '0', '3', '')  
  
            SET @n_err = @@ERROR  
            IF @n_err <> 0  
            BEGIN  
               IF @@TRANCOUNT >= 1  
               BEGIN  
                  ROLLBACK TRAN  
                  GOTO FAILURE  
               END  
            END  
            ELSE  
            BEGIN  
               IF @@TRANCOUNT > 0  
               BEGIN  
                  COMMIT TRAN  
               END  
               ELSE  
               BEGIN  
                  ROLLBACK TRAN  
                  GOTO FAILURE  
               END  
            END -- @n_err <> 0  
         END -- NOT Exists    
  
         FETCH NEXT FROM CUR_PS  
         INTO @c_Loadkey  
            , @c_orderkey  
      END -- WHILE  
      CLOSE CUR_PS  
      DEALLOCATE CUR_PS

      UPDATE #temp_pick  
      SET PickSlipNo = PICKHEADER.PickHeaderKey  
      FROM PICKHEADER (NOLOCK)  
      WHERE PICKHEADER.ExternOrderKey = #temp_pick.LoadKey  
      AND   PICKHEADER.OrderKey = #temp_pick.OrderKey  
      AND   PICKHEADER.Zone = '3'  
      AND   (#temp_pick.PickSlipNo IS NULL OR RTRIM(#temp_pick.PickSlipNo) = '') 
   END
   GOTO SUCCESS 

   --FAILURE:  
   --IF OBJECT_ID('tempdb..#temp_pick') IS NOT NULL  
   --   DROP TABLE #temp_pick  
   
   SUCCESS:  
   IF @c_PreGenRptData = 'Y'  
   BEGIN  
      DECLARE CUR_SCANIN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT DISTINCT LoadKey  
      FROM #temp_pick  
  
      OPEN CUR_SCANIN  
  
      FETCH NEXT FROM CUR_SCANIN  
      INTO @c_Loadkey  
  
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         IF (  SELECT COUNT(DISTINCT StorerKey)  
               FROM ORDERS WITH (NOLOCK)  
               JOIN LoadPlanDetail (NOLOCK) ON (LoadPlanDetail.OrderKey = ORDERS.OrderKey)  
               WHERE LoadPlanDetail.LoadKey = @c_Loadkey) = 1  
         BEGIN  
            -- Only 1 storer found          
            SET @c_StorerKey = N''  
  
            SELECT TOP 1 @c_StorerKey = ORDERS.StorerKey  
            FROM ORDERS WITH (NOLOCK)  
            JOIN LoadPlanDetail WITH (NOLOCK) ON (LoadPlanDetail.OrderKey = ORDERS.OrderKey)  
            WHERE LoadPlanDetail.LoadKey = @c_Loadkey  
  
            IF EXISTS (  SELECT 1  
                         FROM StorerConfig WITH (NOLOCK)  
                         WHERE ConfigKey = 'AUTOSCANIN' AND SValue = '1' AND StorerKey = @c_StorerKey)  
            BEGIN  
               -- Configkey is setup          
               DECLARE CUR_PI CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT PickSlipNo  
               FROM #temp_pick  
               WHERE PickSlipNo IS NOT NULL OR RTRIM(PickSlipNo) <> ''  
               ORDER BY PickSlipNo  
  
               OPEN CUR_PI  
  
               FETCH NEXT FROM CUR_PI  
               INTO @c_PickSlipNo  
  
               WHILE (@@FETCH_STATUS <> -1)  
               BEGIN  
  
                  IF NOT EXISTS (  SELECT 1  
                                   FROM PickingInfo WITH (NOLOCK)  
                                   WHERE PickSlipNo = @c_PickSlipNo)  
                  BEGIN  
                     INSERT INTO PickingInfo (PickSlipNo, ScanInDate, PickerID, ScanOutDate)  
                     VALUES (@c_PickSlipNo, GETDATE(), SUSER_SNAME(), NULL)  
                  END  
                  FETCH NEXT FROM CUR_PI  
                  INTO @c_PickSlipNo  
               END  
            CLOSE CUR_PI  
            DEALLOCATE CUR_PI 
            END -- Configkey is setup          
             
         END -- Only 1 storer found   
  
         FETCH NEXT FROM CUR_SCANIN  
         INTO @c_Loadkey  
      END  
      CLOSE CUR_SCANIN  
      DEALLOCATE CUR_SCANIN
   END
   --select * from #temp_pick(NOLOCK) order by sku
   IF ISNULL(@c_PreGenRptData,'') = ''
   BEGIN
      DECLARE CUR_Update CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT DISTINCT SKU  
      FROM #temp_pick  
  
      OPEN CUR_Update  
  
      FETCH NEXT FROM CUR_Update  
      INTO @c_Sku  
  
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
       
         SELECT @c_SUMQty = COUNT(DISTINCT PD.SKU)
         FROM WAVEDETAIL WD (NOLOCK)
         JOIN PICKDETAIL PD (NOLOCK) ON WD.ORDERKEY = PD.ORDERKEY
         WHERE WD.WAVEKEY = @c_Wavekey
         AND LEFT(PD.SKU, 8) = LEFT(@c_SKU,8)
         GROUP BY LEFT(PD.SKU, 8)
         
         UPDATE #temp_pick
         SET countsku = @c_SUMQty
         WHERE SKU = @c_sku
         FETCH NEXT FROM CUR_Update  
         INTO @c_Sku  
      END  
      CLOSE CUR_Update  
      DEALLOCATE CUR_Update

   INSERT INTO #temp_pick2 (Wavekey, SKU, Pcs, CountSku, TotalPcs, TotalSku, Loadkey)
            SELECT Wavekey AS Wavekey
         , LEFT(SKU, 8) AS Generic
         , SUM(Pcs) AS Pcs
         , CountSku AS CountSku
         , @n_TotalPcs AS TotalPcs
         , TotalSku AS TotalSku
         , Loadkey
   FROM #temp_pick(NOLOCK)
            GROUP BY Wavekey,  LEFT(SKU, 8), Loadkey, countsku,TotalSku

            SELECT @n_TotalSku = SUM(CountSku)
            FROM #temp_pick2(NOLOCK)

             UPDATE #temp_pick
         SET TotalSku = @n_TotalSku

   END

   SELECT Wavekey AS Wavekey
         , LEFT(SKU, 8) AS Generic
         , SUM(Pcs) AS Pcs
         , CountSku AS CountSku
         , @n_TotalPcs AS TotalPcs
         , TotalSku AS TotalSku
         , Loadkey
   FROM #temp_pick(NOLOCK)
            GROUP BY Wavekey,  LEFT(SKU, 8), Loadkey, countsku,TotalSku
            ORDER BY LEFT(SKU, 8)   --WZ01

   IF OBJECT_ID('tempdb..#temp_pick') IS NOT NULL  
      DROP TABLE #temp_pick

   IF OBJECT_ID('tempdb..#temp_pick2') IS NOT NULL  
      DROP TABLE #temp_pick2

   IF CURSOR_STATUS('LOCAL', 'CUR_SCANIN') IN ( 0, 1 )  
   BEGIN  
      CLOSE CUR_SCANIN  
      DEALLOCATE CUR_SCANIN  
   END  
  
   IF CURSOR_STATUS('LOCAL', 'CUR_PI') IN ( 0, 1 )  
   BEGIN  
      CLOSE CUR_PI  
      DEALLOCATE CUR_PI  
   END  
   
   IF CURSOR_STATUS('LOCAL', 'CUR_PICK') IN ( 0, 1 )  
   BEGIN  
      CLOSE CUR_PICK  
      DEALLOCATE CUR_PICK  
   END  

END -- procedure    

GO