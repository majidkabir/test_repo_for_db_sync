SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Stored Proc : nsp_GetPickSlipOrders03e                                  */
/* Creation Date:                                                          */
/* Copyright: IDS                                                          */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose: Change to call individual SP for r_dw_print_pickorder03e       */
/*          instead of nsp_GetPickSlipOrders03d SP                         */
/*          (Modified from nsp_GetPickSlipOrders03d)                       */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Local Variables:                                                        */
/*                                                                         */
/* Called By: r_dw_print_pickorder03e                                      */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date        Author      Ver   Purposes                                  */
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */
/***************************************************************************/

CREATE PROC [dbo].[nsp_GetPickSlipOrders03e]
(
   @c_loadkey NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @c_pickheaderkey       NVARCHAR(10),
         @n_continue           INT,
         @c_errmsg             NVARCHAR(255),
         @b_success            INT,
         @n_err                INT,
         @c_sku                NVARCHAR(20),
         @n_qty                INT,
         @c_loc                NVARCHAR(10),
         @n_cases              INT,
         @n_perpallet          INT,
         @c_storer             NVARCHAR(15),
         @c_orderkey           NVARCHAR(10),
         @c_ConsigneeKey       NVARCHAR(15),
         @c_Company            NVARCHAR(45),
         @c_Addr1              NVARCHAR(45),
         @c_Addr2              NVARCHAR(45),
         @c_Addr3              NVARCHAR(45),
         @c_PostCode           NVARCHAR(15),
         @c_Route              NVARCHAR(10),
         @c_Route_Desc         NVARCHAR(60), -- RouteMaster.Desc
         @c_TrfRoom            NVARCHAR(5),  -- LoadPlan.TrfRoom
         @c_Notes1             NVARCHAR(200),
         @c_Notes2             NVARCHAR(200), 
         @c_SkuDesc            NVARCHAR(60),
         @n_CaseCnt            INT,
         @n_PalletCnt          INT,
         @c_ReceiptTm          NVARCHAR(20),
         @c_PrintedFlag        NVARCHAR(1),
         @c_UOM                NVARCHAR(10),
         @n_UOM3               INT,
         @c_Lot                NVARCHAR(10),
         @c_StorerKey          NVARCHAR(15),
         @c_Zone               NVARCHAR(1),
         @n_PgGroup            INT,
         @n_TotCases           INT,
         @n_RowNo              INT,
         @c_PrevSKU            NVARCHAR(20),
         @n_SKUCount           INT,
         @c_Carrierkey         NVARCHAR(60),
         @c_VehicleNo          NVARCHAR(10),
         @c_firstorderkey      NVARCHAR(10),
         @c_superorderflag     NVARCHAR(1),
         @c_firsttime          NVARCHAR(1),
         @c_logicalloc         NVARCHAR(18),
         @c_Lottable01         NVARCHAR(18),
         @c_Lottable02         NVARCHAR(18),
         @c_Lottable03         NVARCHAR(18),
         @d_Lottable04         DATETIME,
         @d_Lottable05         DATETIME,
         @n_packpallet         INT,
         @n_packcasecnt        INT,
         @c_externorderkey     NVARCHAR(50),  --tlting_ext
         @n_pickslips_required INT,
         @dt_deliverydate      DATETIME

DECLARE @c_PrevOrderKey NVARCHAR(10),
         @n_Pallets     INT,
         @n_Cartons     INT,
         @n_Eaches      INT,
         @n_UOMQty      INT,
         @c_InvoiceNo   NVARCHAR(10)  

DECLARE @n_starttcnt INT

SELECT @n_starttcnt = @@TRANCOUNT
SELECT @n_pickslips_required = 0 -- (Leong01)

WHILE @@TRANCOUNT > 0
BEGIN
   COMMIT TRAN
END

BEGIN TRAN
   CREATE TABLE #temp_pick                                              
      (     PickSlipNo     NVARCHAR(10)   NULL                           
         ,  LoadKey        NVARCHAR(10)                                
         ,  OrderKey       NVARCHAR(10)                                
         ,  ConsigneeKey   NVARCHAR(15)                                
         ,  Company        NVARCHAR(45)                                
         ,  Addr1          NVARCHAR(45)   NULL                           
         ,  Addr2          NVARCHAR(45)   NULL                           
         ,  Addr3          NVARCHAR(45)   NULL                           
         ,  PostCode       NVARCHAR(15)   NULL                           
         ,  Route          NVARCHAR(10)   NULL                           
         ,  Route_Desc     NVARCHAR(60)   NULL  -- RouteMaster.Desc      
         ,  TrfRoom        NVARCHAR(5)    NULL  -- LoadPlan.TrfRoom      
         ,  Notes1         NVARCHAR(200)  NULL                           
         ,  Notes2         NVARCHAR(200)  NULL                           
         ,  LOC            NVARCHAR(10)   NULL                           
         ,  SKU            NVARCHAR(20)                                
         ,  SkuDesc        NVARCHAR(60)                                
         ,  Qty            INT                                         
         ,  TempQty1       INT                                         
         ,  TempQty2       INT                                         
         ,  PrintedFlag    NVARCHAR(1)    NULL                           
         ,  Zone           NVARCHAR(1)                                 
         ,  PgGroup        INT                                         
         ,  RowNum         INT                                         
         ,  Lot            NVARCHAR(10)                                
         ,  Carrierkey     NVARCHAR(60)   NULL                           
         ,  VehicleNo      NVARCHAR(10)   NULL                           
         ,  Lottable01     NVARCHAR(18)   NULL                           
         ,  Lottable02     NVARCHAR(18)   NULL                           
         ,  Lottable03     NVARCHAR(18)   NULL                           
         ,  Lottable04     DATETIME       NULL                           
         ,  Lottable05     DATETIME       NULL                           
         ,  packpallet     INT                                         
         ,  packcasecnt    INT                                         
         ,  externorderkey NVARCHAR(50)   NULL      --tlting_ext
         ,  LogicalLoc     NVARCHAR(18)   NULL                           
         ,  DeliveryDate   DATETIME       NULL                           
         ,  Uom            NVARCHAR(10)                                
         ,  InvoiceNo      NVARCHAR(10)   NULL                           
         ,  Ovas           CHAR(30)       NULL                           
         ,  Putawayzone    NVARCHAR(10)   NULL   
         ,  Storerkey      NVARCHAR(15)   NULL                           
         ,  PickByCase     INT            NULL                                                          
         )                                                             

   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 8 - By Order
   IF EXISTS ( SELECT 1
               FROM PickHeader (NOLOCK)
               WHERE ExternOrderKey = @c_loadkey
               AND Zone = "3" )
   BEGIN
      SELECT @c_firsttime = 'N'
      SELECT @c_PrintedFlag = 'Y'
   END
   ELSE
   BEGIN
      SELECT @c_firsttime = 'Y'
      SELECT @c_PrintedFlag = "N"
   END -- Record Not Exists

   INSERT INTO #Temp_Pick
         (  PickSlipNo             
         ,  LoadKey                
         ,  OrderKey   
         ,  Storerkey            
         ,  ConsigneeKey           
         ,  Company                
         ,  Addr1                  
         ,  Addr2                  
         ,  PgGroup                
         ,  Addr3                  
         ,  PostCode               
         ,  Route                  
         ,  Route_Desc             
         ,  TrfRoom                
         ,  Notes1                 
         ,  RowNum                 
         ,  Notes2                 
         ,  LOC                    
         ,  SKU                    
         ,  SkuDesc                
         ,  Qty                    
         ,  TempQty1               
         ,  TempQty2               
         ,  PrintedFlag            
         ,  Zone                   
         ,  Lot                    
         ,  CarrierKey             
         ,  VehicleNo              
         ,  Lottable01             
         ,  Lottable02             
         ,  Lottable03             
         ,  Lottable04             
         ,  Lottable05             
         ,  packpallet             
         ,  packcasecnt            
         ,  externorderkey         
         ,  LogicalLoc             
         ,  DeliveryDate           
         ,  UOM                    
         ,  InvoiceNo              
         ,  Ovas                   
         ,  Putawayzone 
         ) 
   SELECT ( SELECT PickHeaderkey
            FROM PICKHEADER (NOLOCK)
            WHERE ExternOrderKey = @c_LoadKey
            AND OrderKey = PickDetail.OrderKey
            AND Zone = '3'
          ) 
         ,@c_LoadKey                                  AS LoadKey 
         ,PICKDETAIL.OrderKey 
         ,ORDERS.Storerkey                            AS Storerkey   
         ,ISNULL(RTRIM(ORDERS.BillToKey), '')         AS ConsigneeKey
         ,ISNULL(RTRIM(ORDERS.c_Company), '')         AS Company 
         ,ISNULL(RTRIM(ORDERS.C_Address1), '')        AS Addr1 
         ,ISNULL(RTRIM(ORDERS.C_Address2), '')        AS Addr2 
         ,0                                           AS PgGroup 
         ,ISNULL(RTRIM(ORDERS.C_Address3), '')        AS Addr3
         ,ISNULL(RTRIM(ORDERS.C_Zip), '')             AS PostCode 
         ,ISNULL(RTRIM(ORDERS.Route), '')             AS Route 
         ,ISNULL(RTRIM(ROUTEMASTER.Descr), '')        AS  Route_Desc 
         ,ISNULL(RTRIM(ORDERS.Door), '')              AS TrfRoom 
         ,CONVERT(NVARCHAR(200), ISNULL(RTRIM(ORDERS.Notes), ''))    AS Notes1  
         ,0                                           AS RowNo 
         ,CONVERT(NVARCHAR(200), ISNULL(RTRIM(ORDERS.Notes2), ''))   AS Notes2 
         ,ISNULL(RTRIM(PICKDETAIL.loc), '')           AS loc
         ,ISNULL(RTRIM(PICKDETAIL.sku), '')           AS Sku
         ,ISNULL(RTRIM(SKU.Descr), '')                AS SkuDesc
         ,ISNULL(SUM(PICKDETAIL.qty),0)               AS Qty                                   
         ,CASE PICKDETAIL.UOM
            WHEN '1' THEN PACK.Pallet
            WHEN '2' THEN PACK.CaseCnt
            WHEN '3' THEN PACK.InnerPack
            ELSE 1
          END                                         AS UOMQty
         ,0                                           AS TempQty2
         ,ISNULL(( SELECT DISTINCT
                   'Y'
                   FROM PickHeader (NOLOCK)
                   WHERE ExternOrderKey = @c_LoadKey
                   AND Zone = '3'
                 ), 'N')                              AS PrintedFlag 
         ,'3'                                         AS Zone 
         ,ISNULL(RTRIM(PICKDETAIL.Lot),'')            AS Lot
         ,''                                          AS CarrierKey 
         ,''                                          AS VehicleNo 
         ,ISNULL(RTRIM(LOTATTRIBUTE.Lottable01),'')   AS Lottable01
         ,ISNULL(RTRIM(LOTATTRIBUTE.Lottable02),'')   AS Lottable02
         ,ISNULL(RTRIM(LOTATTRIBUTE.Lottable03),'')   AS Lottable03
         ,ISNULL(LOTATTRIBUTE.Lottable04, '19000101') AS Lottable04
         ,ISNULL(LOTATTRIBUTE.Lottable05, '19000101') AS Lottable05
         ,ISNULL(PACK.Pallet,0)                    AS Pallet
         ,ISNULL(PACK.CaseCnt,0)                   AS CaseCnt
         ,ISNULL(RTRIM(ORDERS.ExternOrderKey),'')  AS ExternOrderKey
         ,ISNULL(RTRIM(LOC.LogicalLocation), '')   AS LogicalLocation
         ,ISNULL(ORDERS.DeliveryDate, '19000101')  AS DeliveryDate
         ,ISNULL(RTRIM(PACK.PackUOM3),'')          AS PackUOM3
         ,ISNULL(RTRIM(ORDERS.InvoiceNo),'')       AS InvoiceNo
         ,ISNULL(RTRIM(SKU.Ovas),'')               AS Ovas
         ,ISNULL(RTRIM(LOC.Putawayzone),'')        AS Putawayzone
   
         FROM LOADPLANDETAIL WITH (NOLOCK)
         JOIN ORDERS        WITH (NOLOCK) ON ( ORDERS.Orderkey = LoadPlanDetail.Orderkey )
         JOIN STORER        WITH (NOLOCK) ON ( ORDERS.StorerKey = Storer.StorerKey )
         LEFT OUTER JOIN ROUTEMASTER WITH (NOLOCK) ON ( ROUTEMASTER.Route = ORDERS.Route )
         JOIN PICKDETAIL    WITH (NOLOCK) ON ( PICKDETAIL.OrderKey = ORDERS.Orderkey )
         JOIN LOTATTRIBUTE  WITH (NOLOCK) ON ( PICKDETAIL.Lot = LOTATTRIBUTE.Lot )
         JOIN SKU           WITH (NOLOCK) ON ( Sku.StorerKey = PICKDETAIL.StorerKey )
                                          AND( Sku.Sku = PICKDETAIL.Sku )
         JOIN PACK          WITH (NOLOCK) ON ( SKU.Packkey = PACK.Packkey )
         JOIN LOC           WITH (NOLOCK) ON ( PICKDETAIL.LOC = LOC.LOC )
         WHERE PICKDETAIL.Status >= '0'
         AND LOADPLANDETAIL.LoadKey = @c_LoadKey
         GROUP BY PICKDETAIL.OrderKey 
         ,ORDERS.Storerkey  
         ,ISNULL(RTRIM(ORDERS.BillToKey), '') 
         ,ISNULL(RTRIM(ORDERS.c_Company), '') 
         ,ISNULL(RTRIM(ORDERS.C_Address1), '') 
         ,ISNULL(RTRIM(ORDERS.C_Address2), '') 
         ,ISNULL(RTRIM(ORDERS.C_Address3), '') 
         ,ISNULL(RTRIM(ORDERS.C_Zip), '') 
         ,ISNULL(RTRIM(ORDERS.Route), '') 
         ,ISNULL(RTRIM(ROUTEMASTER.Descr), '') 
         ,ISNULL(RTRIM(ORDERS.Door), '') 
         ,CONVERT(NVARCHAR(200), ISNULL(RTRIM(ORDERS.Notes), ''))   
         ,CONVERT(NVARCHAR(200), ISNULL(RTRIM(ORDERS.Notes2), ''))   
         ,ISNULL(RTRIM(PICKDETAIL.loc), '') 
         ,ISNULL(RTRIM(PICKDETAIL.sku), '') 
         ,ISNULL(RTRIM(SKU.Descr), '')
         ,CASE PICKDETAIL.UOM
            WHEN '1' THEN PACK.Pallet
            WHEN '2' THEN PACK.CaseCnt
            WHEN '3' THEN PACK.InnerPack
            ELSE 1
          END 
         ,ISNULL(RTRIM(PICKDETAIL.Lot),'')
         ,ISNULL(RTRIM(LOTATTRIBUTE.Lottable01),'')
         ,ISNULL(RTRIM(LOTATTRIBUTE.Lottable02),'')
         ,ISNULL(RTRIM(LOTATTRIBUTE.Lottable03),'')
         ,ISNULL(LOTATTRIBUTE.Lottable04, '19000101')
         ,ISNULL(LOTATTRIBUTE.Lottable05, '19000101')
         ,ISNULL(PACK.Pallet,0) 
         ,ISNULL(PACK.CaseCnt,0) 
         ,ISNULL(RTRIM(ORDERS.ExternOrderKey),'')
         ,ISNULL(RTRIM(LOC.LogicalLocation), '') 
         ,ISNULL(ORDERS.DeliveryDate, '19000101') 
         ,ISNULL(RTRIM(PACK.PackUOM3),'')      
         ,ISNULL(RTRIM(ORDERS.InvoiceNo),'')   
         ,ISNULL(RTRIM(SKU.ovas),'')         
         ,ISNULL(RTRIM(LOC.Putawayzone),'')

   BEGIN TRAN
   -- Uses PickType as a Printed Flag
   UPDATE PickHeader
      SET PickType = '1' 
         ,TrafficCop = NULL
   WHERE ExternOrderKey = @c_loadkey
   AND Zone = "3"
   AND PickType = '0'

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

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   SELECT @n_pickslips_required = COUNT(DISTINCT OrderKey)
   FROM #TEMP_PICK
   WHERE ISNULL(RTRIM(PickSlipNo),'') = '' 

   IF @@ERROR <> 0
   BEGIN
      GOTO FAILURE
   END
   ELSE
   IF @n_pickslips_required > 0
   BEGIN
      BEGIN TRAN

      EXECUTE nspg_GetKey 'PICKSLIP', 9, @c_pickheaderkey OUTPUT,
                          @b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, 0,
                          @n_pickslips_required

      COMMIT TRAN

      BEGIN TRAN
      INSERT INTO PICKHEADER
         (  PickHeaderKey 
         ,  OrderKey 
         ,  ExternOrderKey 
         ,  PickType 
         ,  Zone 
         ,  TrafficCop
         )
      SELECT 'P' + RIGHT(REPLICATE('0', 9)
                 + dbo.fnc_LTrim(dbo.fnc_RTrim(STR(CAST(@c_pickheaderkey AS INT)
                 + ( SELECT
                     COUNT(DISTINCT orderkey)
                     FROM
                     #TEMP_PICK AS Rank
                     WHERE
                     Rank.OrderKey < #TEMP_PICK.OrderKey
                     AND ISNULL(RTRIM(Rank.PickSlipNo),'') = ''  
                   ))-- str
                   ))-- dbo.fnc_RTrim
                 , 9),
               OrderKey,
               LoadKey,
               '0',
               '3',
               ''
      FROM #TEMP_PICK
      WHERE ISNULL(RTRIM(PickSlipNo),'') = '' 
      GROUP BY LoadKey,
               OrderKey

      UPDATE #TEMP_PICK
         SET PickSlipNo = PICKHEADER.PickHeaderKey
      FROM PICKHEADER (NOLOCK)
      WHERE PICKHEADER.ExternOrderKey = #TEMP_PICK.LoadKey
        AND PICKHEADER.OrderKey = #TEMP_PICK.OrderKey
        AND PICKHEADER.Zone = '3'
        AND ISNULL(RTRIM(#TEMP_PICK.PickSlipNo),'') = '' 

      UPDATE PICKDETAIL
         SET PickSlipNo = #TEMP_PICK.PickSlipNo,
             TrafficCop = NULL
      FROM #TEMP_PICK
      WHERE #TEMP_PICK.OrderKey = PICKDETAIL.OrderKey
        AND ISNULL(RTRIM(PICKDETAIL.PickSlipNo),'') = ''  

      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END
   END

   GOTO SUCCESS

   FAILURE:
   DELETE FROM #TEMP_PICK

   SUCCESS:
   UPDATE #TEMP_PICK
   SET PickByCase = ISNULL(CASE WHEN CODELKUP.Code = 'PickByCase' THEN 1 ELSE 0 END,0)  
   FROM #TEMP_PICK
   LEFT JOIN CODELKUP WITH (NOLOCK) ON ( CODELKUP.ListName = 'REPORTCFG' )
                                    AND( CODELKUP.Storerkey= #TEMP_PICK.Storerkey )
                                    AND( CODELKUP.Long = 'r_dw_print_pickorder03e')
                                    AND( CODELKUP.Short <> 'N' OR  CODELKUP.Short IS NULL )
   SELECT PickSlipNo      
         , LoadKey         
         , OrderKey        
         , ConsigneeKey    
         , Company         
         , Addr1           
         , Addr2           
         , Addr3           
         , PostCode        
         , Route           
         , Route_Desc      
         , TrfRoom         
         , Notes1          
         , Notes2          
         , LOC             
         , SKU             
         , SkuDesc         
         , QtyCase = CASE WHEN PickByCase = 1 AND PackCaseCnt > 0 THEN (Qty % PackCaseCnt)
                          ELSE Qty END             
         , TempQty1        
         , TempQty2        
         , PrintedFlag     
         , Zone            
         , PgGroup         
         , RowNum          
         , Lot             
         , Carrierkey      
         , VehicleNo       
         , Lottable01      
         , Lottable02      
         , Lottable03     
         , Lottable04      
         , Lottable05      
         , packpallet      
         , packcasecnt     
         , externorderkey  
         , LogicalLoc      
         , DeliveryDate    
         , Uom             
         , InvoiceNo       
         , Ovas            
         , Putawayzone 
         , PickByCase
         , QtyCase = CASE WHEN PickByCase = 1 AND PackCaseCnt > 0 THEN FLOOR(Qty / PackCaseCnt)
                          ELSE 0 END  
         , Qty  
   FROM #TEMP_PICK

   DROP TABLE #TEMP_PICK

   WHILE @@TRANCOUNT < @n_starttcnt
   BEGIN
      BEGIN TRAN
   END
END

GO