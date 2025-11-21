SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_GetPickSlipOrders43                            */  
/* Creation Date: 22-Nov-2011                                           */  
/* Copyright: IDS                                                       */  
/* Written by: NJOW                                                     */  
/*                                                                      */  
/* Purpose: S230799 - LCI Pickslip (modify from nsp_GetPickSlipOrders39)*/  
/*          -Pickslip by Pickzone                                       */
/*          -One SKU will be located in 1 pickzone only & never         */
/*           multiple pickzone                                          */                           
/*                                                                      */  
/* Called By: r_dw_print_pickorder43                                    */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Ver   Purposes                                  */  
/* 10-01-2012   ChewKP  1.0   Standardize ConsoOrderKey Mapping         */
/*                            (ChewKP01)                                */
/* 11-JAN-2012  YTWan   1.01  Change Request. (wan01)                   */
/* 31-JAN-2012  NJOW01  1.02  Remove break by pickzone                  */
/* 13-FEB-2012  YTWAN   1.03  SOS#235640. Print PickSlip from Wave.     */
/*                            (Wan02)                                   */
/* 16-MAR-2012  KPCHEW  1.04  Fixes when PickSlip exist do not create   */
/*                            (ChewKP02)                                */
/************************************************************************/  
  
CREATE PROC [dbo].[isp_GetPickSlipOrders43] (@c_wavekey NVARCHAR(10))                                  --(Wan02)
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @c_pickheaderkey      NVARCHAR(10),  
           @n_continue           int,  
           @c_errmsg             NVARCHAR(255),  
           @b_success            int,  
           @n_err                int,  
           @c_ConsoOrderkey      NVARCHAR(30),
           @c_Orderkey           NVARCHAR(10),
           @c_Pickzone           NVARCHAR(10),
           @c_Pickdetailkey      NVARCHAR(10),
           @c_PrevLoadkey        NVARCHAR(10),
           @c_PrevConsoOrderkey  NVARCHAR(30),
           @c_PrevPickzone       NVARCHAR(10),
           @c_Pickslipno         NVARCHAR(10),
           @c_Orderlinenumber    NVARCHAR(5),
           @c_LoadKey            NVARCHAR(10)                                                          --(Wan02)
                
    SELECT RefKeyLookup.PickSlipNo,                                                                  
           ORDERS.Billtokey,  
           ORDERS.B_Company,  
           ORDERS.B_Address1,  
           ORDERS.B_Address2,  
           ISNULL(ORDERS.B_City,'') AS B_City,  
           ISNULL(ORDERS.B_State,'') AS B_State,  
           ISNULL(ORDERS.B_Zip,'') AS B_Zip,  
           ORDERS.Consigneekey,  
           ORDERS.C_Company,  
           ORDERS.C_Address1,  
           ORDERS.C_Address2,  
           ISNULL(ORDERS.C_City,'') AS C_City,  
           ISNULL(ORDERS.C_State,'') AS C_State,  
           ISNULL(ORDERS.C_Zip,'') AS C_Zip,  
           ORDERS.Externorderkey,  
           MAX(ORDERS.Deliverydate) AS Deliverydate,  
           MAX(ORDERS.C_fax2) AS C_Fax2,  
           MAX(ORDERS.M_Fax1) AS M_Fax1,  
           MAX(ORDERS.Userdefine09) AS UDF9Wavekey,  
           ORDERS.Invoiceno,  
           ORDERDETAIL.ConsoOrderkey, 
           --(Wan02) - START  
           --LOADPLAN.Loadkey, 
           ORDERS.LoadKey, 
           --(Wan02) - END
           PICKDETAIL.Loc,  
           SKU.Style,  
           SKU.Color,  
           SKU.Size,  
           SKU.Busr1,  
           SKU.Busr8,                  
           SUM(PICKDETAIL.Qty) AS Qty,  
           ORDERDETAIL.Sku,  
           ORDERDETAIL.Userdefine01 AS ODUserdefine01,  
           ORDERDETAIL.Userdefine02 AS ODUserdefine02,  
           ORDERDETAIL.Userdefine05 AS ODUserdefine05,  
           ISNULL(SUBSTRING(MAX(CAST(ORDERS.Notes AS NVARCHAR(1000))),1,250),'') AS Notes1a,  
           ISNULL(SUBSTRING(MAX(CAST(ORDERS.Notes AS NVARCHAR(1000))),251,250),'') AS Notes1b,  
           ISNULL(SUBSTRING(MAX(CAST(ORDERS.Notes AS NVARCHAR(1000))),501,250),'') AS Notes1c,  
           ISNULL(SUBSTRING(MAX(CAST(ORDERS.Notes AS NVARCHAR(1000))),751,250),'') AS Notes1d,  
           ISNULL(SUBSTRING(MAX(CAST(ORDERS.Notes2 AS NVARCHAR(1000))),1,250),'') AS Notes2a,  
           ISNULL(SUBSTRING(MAX(CAST(ORDERS.Notes2 AS NVARCHAR(1000))),251,250),'') AS Notes2b,             
           ISNULL(SUBSTRING(MAX(CAST(ORDERS.Notes2 AS NVARCHAR(1000))),501,250),'') AS Notes2c,  
           ISNULL(SUBSTRING(MAX(CAST(ORDERS.Notes2 AS NVARCHAR(1000))),751,250),'') AS Notes2d,  
           STORER.Company,  
           FACILITY.Descr,  
           FACILITY.Userdefine01 AS FUserdefine01,  
           FACILITY.Userdefine03 AS FUserdefine03,  
           RTRIM(LEFT(FACILITY.Userdefine04,5))+'-'+RTRIM(LTRIM(RIGHT(FACILITY.Userdefine04,4))) AS FUSERDEFINE45,  
           suser_sname() AS UserName,  
           ISNULL((SELECT Distinct 'Y' FROM PickHeader WITH (NOLOCK) WHERE PickHeader.PickHeaderkey = RefKeyLookup.PickSlipNo
                   AND PickHeader.Zone = 'LP') , 'N') AS PrintedFlag,  
           MAX(ORDERS.Pokey) AS Pokey,  
           LOC.Putawayzone,   
           LOC.Logicallocation,  
           '' AS Pickzone, --NJOW01
           ISNULL(STORER.Address1,'') AS Address1,  
           ISNULL(STORER.Address2,'') AS Address2,  
           ISNULL(STORER.City,'') AS City,  
           ISNULL(STORER.State,'') AS State,  
           ISNULL(STORER.Zip,'') AS Zip,             
           ISNULL(STORER.Phone1,'') AS Phone1,             
           ISNULL(STORER.Fax1,'') AS Fax1,  
           ORDERS.B_Contact1,  
           ORDERS.C_Contact1,  
           ORDERDETAIL.ManufacturerSku,  
           CONVERT(NVARCHAR(255),ISNULL(STORER.Notes1,''))  AS Remarks,
           MAX(ORDERS.Route) AS Route,
           MAX(ORDERS.M_Phone2) AS M_Phone2,
           SKU.Measurement,
           CONVERT(DECIMAL(12,4),SKU.StdCube) AS StdCube,
           CONVERT(DECIMAL(12,2),SKU.StdGrossWgt) AS StdGrossWgt
           --STORER.Storerkey AS SCAC,
           --STORER.Company AS SCACName
    INTO #TEMP_PICK 
    --(Wan02) - START            
    --FROM LOADPLAN (NOLOCK)   
    --JOIN LOADPLANDETAIL (NOLOCK) ON (LOADPLAN.Loadkey = LOADPLANDETAIL.Loadkey) 
	 FROM WAVE WITH (NOLOCK)
	 JOIN WAVEDETAIL WITH (NOLOCK) ON (WAVEDETAIL.Wavekey = WAVE.Wavekey)
	 JOIN ORDERS WITH (NOLOCK) ON (ORDERS.Orderkey = WAVEDETAIL.Orderkey) 
    --JOIN ORDERS (NOLOCK) ON (LOADPLANDETAIL.Orderkey = ORDERS.Orderkey)
    --(Wan02) - END   
    JOIN ORDERDETAIL (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)  
    JOIN FACILITY (NOLOCK) ON (ORDERS.Facility = FACILITY.Facility)  
    JOIN STORER (NOLOCK) ON (ORDERS.Storerkey = STORER.Storerkey)  
    JOIN SKU (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey   
                          AND ORDERDETAIL.Sku = SKU.Sku)   
    JOIN PICKDETAIL (NOLOCK) ON (ORDERDETAIL.Orderkey = PICKDETAIL.Orderkey   
                                 AND ORDERDETAIL.Orderlinenumber = PICKDETAIL.Orderlinenumber)  
    JOIN LOC (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc)  
    LEFT OUTER JOIN RefKeyLookup (NOLOCK) ON (RefKeyLookup.PickDetailKey = PICKDETAIL.PickDetailKey)
    --(Wan02) - START
    --WHERE LOADPLAN.Loadkey = @c_loadkey  
    WHERE WAVE.Wavekey = @c_wavekey
    --(Wan02) - END
    GROUP BY RefKeyLookup.PickSlipNo,  
           ORDERS.Billtokey,  
           ORDERS.B_Company,  
           ORDERS.B_Address1,  
           ORDERS.B_Address2,  
           ISNULL(ORDERS.B_City,''),  
           ISNULL(ORDERS.B_State,''),  
           ISNULL(ORDERS.B_Zip,''),  
           ORDERS.Consigneekey,  
           ORDERS.C_Company,  
           ORDERS.C_Address1,  
           ORDERS.C_Address2,  
           ISNULL(ORDERS.C_City,''),  
           ISNULL(ORDERS.C_State,''),  
           ISNULL(ORDERS.C_Zip,''),  
           ORDERS.Externorderkey,  
           --ORDERS.Deliverydate,  
           --ORDERS.C_fax2,  
           --ORDERS.M_Fax1,  
           --ORDERS.Buyerpo,  
           ORDERS.Invoiceno,  
           ORDERDETAIL.ConsoOrderkey,  
           --(Wan02) - START  
           --LOADPLAN.Loadkey, 
           ORDERS.LoadKey, 
           --(Wan02) - END 
           PICKDETAIL.Loc,  
           SKU.Style,  
           SKU.Color,  
           SKU.Size,  
           SKU.Busr1,  
           SKU.Busr8,                  
           ORDERDETAIL.Sku,  
           ORDERDETAIL.Userdefine01,  
           ORDERDETAIL.Userdefine02,  
           ORDERDETAIL.Userdefine05,  
           --ISNULL(SUBSTRING(ORDERS.Notes,1,250),''),  
           --ISNULL(SUBSTRING(ORDERS.Notes,251,250),''),  
           --ISNULL(SUBSTRING(ORDERS.Notes,501,250),''),  
           --ISNULL(SUBSTRING(ORDERS.Notes,751,250),''),  
           --ISNULL(SUBSTRING(ORDERS.Notes2,1,250),''),  
           --ISNULL(SUBSTRING(ORDERS.Notes2,251,250),''),  
           --ISNULL(SUBSTRING(ORDERS.Notes2,501,250),''),  
           --ISNULL(SUBSTRING(ORDERS.Notes2,751,250),''),  
           STORER.Company,  
           FACILITY.Descr,  
           FACILITY.Userdefine01,  
           FACILITY.Userdefine03,  
           RTRIM(LEFT(FACILITY.Userdefine04,5))+'-'+RTRIM(LTRIM(RIGHT(FACILITY.Userdefine04,4))),  
           --ORDERS.Pokey,  
           LOC.Putawayzone,   
           LOC.Logicallocation,  
           --LOC.Pickzone,   --NJOW01
           ISNULL(STORER.Address1,''),  
           ISNULL(STORER.Address2,''),  
           ISNULL(STORER.City,''),   
           ISNULL(STORER.State,''),   
           ISNULL(STORER.Zip,''),  
           ISNULL(STORER.Phone1,''),             
           ISNULL(STORER.Fax1,''),             
           ORDERS.B_Contact1,  
           ORDERS.C_Contact1,  
           ORDERDETAIL.ManufacturerSku,  
           CONVERT(NVARCHAR(255),ISNULL(STORER.Notes1,'')),     
           --ORDERS.Route,
           --ORDERS.M_Phone2,
           SKU.Measurement,
           CONVERT(DECIMAL(12,4),SKU.StdCube),
           CONVERT(DECIMAL(12,2),SKU.StdGrossWgt)
           --STORER.Storerkey,
           --STORER.Company
    --(Wan02) - START
    ORDER BY ORDERS.LoadKey
    --(Wan02) - END

   BEGIN TRAN    
   
   -- Uses PickType as a Printed Flag    
   UPDATE PickHeader WITH (ROWLOCK) SET PickType = '1', TrafficCop = NULL   
       FROM   PickHeader
       JOIN   #TEMP_PICK ON  (PickHeader.ConsoOrderkey = #TEMP_PICK.ConsoOrderkey)
       WHERE  PickHeader.Zone = 'LP'
       AND ISNULL(PickHeader.Wavekey,'') <> ''
--       WHERE ExternOrderKey = @c_LoadKey   
--       AND Zone = 'LP'   
  
   SELECT @n_err = @@ERROR   
   
   IF @n_err <> 0     
   BEGIN    
      SELECT @n_continue = 3    
      IF @@TRANCOUNT >= 1    
      BEGIN    
         ROLLBACK TRAN    
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
         SELECT @n_continue = 3    
         ROLLBACK TRAN    
      END    
   END    

   SET @c_LoadKey = ''  
   SET @c_ConsoOrderKey = ''  
   SET @c_PickDetailKey = ''  
   SET @n_Continue = 1   
  
   DECLARE C_LoadKey_ExternOrdKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
   SELECT DISTINCT LoadKey, ConsoOrderKey, Pickzone   
   FROM   #TEMP_PICK   
   WHERE  PickSlipNo IS NULL or PickSlipNo = ''  
   ORDER BY LoadKey, Pickzone, ConsoOrderkey

   OPEN C_LoadKey_ExternOrdKey   
  
   FETCH NEXT FROM C_LoadKey_ExternOrdKey INTO @c_LoadKey, @c_ConsoOrderKey, @c_Pickzone    
  
   WHILE (@@Fetch_Status <> -1)  
   BEGIN -- while 1  
      IF ISNULL(@c_ConsoOrderKey, '0') = '0'  
         BREAK  
  
      IF @c_PrevLoadKey <> @c_LoadKey OR   
         @c_PrevConsoOrderKey <> @c_ConsoOrderKey OR
         @c_PrevPickzone <> @c_Pickzone   
      BEGIN       
         SET @c_PickSlipNo = ''  
  
-- now possible to have 1 loadkey/orderkey having multiple pickheader record so cannot perform
-- the below checking
--         SELECT @c_PickSlipNo = PICKHEADERKEY  
--         FROM PICKHEADER (NOLOCK)   
--         WHERE ExternOrderKey = @c_LoadKey AND OrderKey = @c_OrderKey  
--           AND Zone = 'LP'  
  
         -- (ChewKP02)
         IF NOT EXISTS ( SELECT 1 FROM dbo.PickHeader WITH (NOLOCK)
                     WHERE ConsoOrderKey = @c_ConsoOrderKey )
         
         BEGIN                     
               EXECUTE nspg_GetKey  
                  'PICKSLIP',  
                  9,     
                  @c_PickSlipNo   OUTPUT,  
                  @b_success      OUTPUT,  
                  @n_err          OUTPUT,  
                  @c_errmsg       OUTPUT  
           
               IF @b_success = 1   
               BEGIN  
                  SELECT @c_PickSlipNo = 'P' + @c_PickSlipNo            
      
                  INSERT PICKHEADER (pickheaderkey, ExternOrderKey,    zone, PickType,   Wavekey, ConsoOrderKey)  --(ChewKP01)
                             VALUES (@c_PickSlipNo, '', 'LP', '0',  @c_PickSlipNo, @c_ConsoOrderKey)  --(ChewKP01)
      
                  IF @@ERROR <> 0   
                  BEGIN  
                     SET @n_Continue = 3   
                     BREAK   
                  END   
               END -- @b_success = 1    
               ELSE   
               BEGIN  
                  BREAK   
               END   
         END
         ELSE
         BEGIN
            -- GET Existing PickSlipNo
            SELECT @c_PickSlipNo = PickHeaderKey 
            FROM PickHeader WITH (NOLOCK)
            WHERE ConsoOrderKey = @c_ConsoOrderKey
            
            
         END
  
         IF @n_Continue = 1   
         BEGIN  
            DECLARE C_PickDetailKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT PickDetail.PickDetailKey, PickDetail.OrderLineNumber, Pickdetail.Orderkey    
            FROM   PickDetail WITH (NOLOCK)  
            JOIN   OrderDetail WITH (NOLOCK) 
                   ON (PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey AND  
                       PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber)
            JOIN   LOC WITH (NOLOCK)
                   ON (PICKDETAIL.Loc = LOC.Loc)
            WHERE  OrderDetail.ConsoOrderKey = @c_ConsoOrderKey    
            AND    OrderDetail.LoadKey  = @c_LoadKey   
            --AND    Loc.PickZone = @c_PickZone  --NJOW01
            ORDER BY PickDetail.PickDetailKey   
  
            OPEN C_PickDetailKey  
  
            FETCH NEXT FROM C_PickDetailKey INTO @c_PickDetailKey, @c_OrderLineNumber, @c_Orderkey   
  
            WHILE @@FETCH_STATUS <> -1  
            BEGIN  
               IF NOT EXISTS (SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @c_PickDetailKey)   
               BEGIN   
                  INSERT INTO RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey)  
                  VALUES (@c_PickDetailKey, @c_PickSlipNo, @c_OrderKey, @c_OrderLineNumber, @c_LoadKey)    
                  
                  UPDATE PICKDETAIL WITH (ROWLOCK)
                  SET Pickslipno = @c_PickSlipNo,
                      TrafficCop = NULL
                  WHERE Pickdetailkey = @c_PickDetailKey                      
               END   
  
               FETCH NEXT FROM C_PickDetailKey INTO @c_PickDetailKey, @c_OrderLineNumber, @c_Orderkey   
            END   
            CLOSE C_PickDetailKey   
            DEALLOCATE C_PickDetailKey   
  
         END   
        
      END -- @c_PrevLoadKey <> @c_LoadKey OR @c_PrevOrderKey <> @c_OrderKey OR  @c_PrevPickzone <> @c_Pickzone   
  
      UPDATE #TEMP_PICK  
         SET PickSlipNo = @c_PickSlipNo  
      WHERE ConsoOrderKey = @c_ConsoOrderKey  
      AND   LoadKey = @c_LoadKey         
      --AND   PickZone = @c_Pickzone --NJOW01
      AND   (PickSlipNo IS NULL OR PickSlipNo = '')  

      SET @c_PrevLoadKey = @c_LoadKey   
      SET @c_PrevConsoOrderKey = @c_ConsoOrderKey 
      SET @c_PrevPickzone = @c_Pickzone 
  
      FETCH NEXT FROM C_LoadKey_ExternOrdKey INTO @c_LoadKey, @c_ConsoOrderKey, @c_Pickzone       
   END -- while 1   
  
   CLOSE C_LoadKey_ExternOrdKey  
   DEALLOCATE C_LoadKey_ExternOrdKey   
  
   SELECT  Pickslipno,                                                                  
           Billtokey,  
           B_Company,  
           B_Address1,  
           B_Address2,  
           B_City,  
           B_State,  
           B_Zip,  
           Consigneekey,  
           C_Company,  
           C_Address1,  
           C_Address2,  
           C_City,  
           C_State,  
           C_Zip,  
           Externorderkey,  
           Deliverydate,  
           C_fax2,  
           M_Fax1,  
           UDF9Wavekey,  
           Invoiceno,  
           ConsoOrderkey,  
           Loadkey,  
           Loc,  
           Style,  
           Color,  
           Size,  
           Busr1,  
           Qty,  
           Sku,  
           ODUserdefine01,  
           ODUserdefine02,  
           ODUserdefine05,  
           Notes1a,  
           Notes1b,  
           Notes1c,  
           Notes1d,  
           Notes2a,  
           Notes2b,             
           Notes2c,  
           Notes2d,  
           Company,  
           Descr,  
           FUserdefine01,  
           FUserdefine03,  
           FUSERDEFINE45,  
           UserName,  
           PrintedFlag,  
           Pokey,  
           Putawayzone,   
           Logicallocation,  
           Address1,  
           Address2,  
           City,  
           State,  
           Zip,             
           Phone1,             
           Fax1,  
           B_Contact1,  
           C_Contact1,  
           ManufacturerSku,  
           Remarks,
           PickZone,       
           Route,
           M_Phone2,
           Measurement,
           StdCube,
           StdGrossWgt
           --SCAC,
           --SCACName
   FROM #TEMP_PICK
   ORDER BY LoadKey, Pickzone, Putawayzone, ConsoOrderKey, Pickslipno                              --(Wan01) Add putawayzone  

  
   DROP Table #TEMP_PICK    

END

GO