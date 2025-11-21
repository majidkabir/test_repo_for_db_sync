SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/  
/* Store Procedure:  nsp_GetPickSlipOrders17                            */  
/* Creation Date: 11-Apr-2005                                           */  
/* Copyright: IDS                                                       */  
/* Written by: MaryVong                                                 */  
/*                                                                      */  
/* Purpose:  Create Normal Pickslip for IDSSG - Ciba Vision (SOS33950)  */  
/*           Note: Copy from nsp_GetPickSlipOrders03 and modified       */  
/*                                                                      */  
/* Input Parameters:  @c_loadkey,  - Loadkey                            */  
/*                                                                      */  
/* Output Parameters:  None                                             */  
/*                                                                      */  
/* Return Status:  None                                                 */  
/*                                                                      */  
/* Usage:  Used for report dw = r_dw_print_pickorder17                  */  
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
/* Date        Author   Ver   Purposes                                  */  
/* 2014-01-13  TLTING   1.1   Commit transaction                        */
/* 28-Jan-2019  TLTING_ext 1.2 enlarge externorderkey field length      */
/*                                                                      */  
/************************************************************************/  
  
CREATE PROC [dbo].[nsp_GetPickSlipOrders17] (@c_loadkey NVARCHAR(10))   
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @c_pickheaderkey NVARCHAR(10),  
    @n_continue    int,  
    @c_errmsg    NVARCHAR(255),  
    @b_success    int,  
    @n_err     int,  
    @c_sku     NVARCHAR(20),  
    @n_qty     int,  
    @c_loc     NVARCHAR(10),  
    @n_cases     int,  
    @n_perpallet   int,  
    @c_storer    NVARCHAR(15),  
    @c_orderkey    NVARCHAR(10),  
      @c_ExternOrderKey    NVARCHAR(50),   --tlting_ext
    @c_ConsigneeKey  NVARCHAR(15),  
    @c_C_Company   NVARCHAR(45),  
    @c_C_Addr1    NVARCHAR(45),  
    @c_C_Addr2    NVARCHAR(45),  
    @c_C_Addr3    NVARCHAR(45),  
    @c_C_Addr4    NVARCHAR(45),  
      @c_C_Zip             NVARCHAR(18),  
    @c_B_Company   NVARCHAR(45),  
    @c_B_Addr1    NVARCHAR(45),  
    @c_B_Addr2    NVARCHAR(45),  
    @c_B_Addr3    NVARCHAR(45),  
    @c_B_Addr4    NVARCHAR(45),  
      @c_B_Zip             NVARCHAR(18),  
    @c_Route     NVARCHAR(10),  
    @c_RouteDescr   NVARCHAR(60), -- RouteMaster.Descr  
    @c_TrfRoom    NVARCHAR(5),  -- LoadPlan.TrfRoom  
    @c_Notes1    NVARCHAR(60),  
    @c_Notes2    NVARCHAR(60),  
    @c_SkuDescr    NVARCHAR(60),  
    @n_CaseCnt    int,  
    @n_PalletCnt   int,  
    @c_ReceiptTm   NVARCHAR(20),  
    @c_PrintedFlag   NVARCHAR(1),  
    @c_UOM     NVARCHAR(10),  
    @n_UOM3     int,  
    @c_Lot     NVARCHAR(10),  
    @c_StorerKey   NVARCHAR(15),  
    @c_Zone     NVARCHAR(1),  
    @n_TotCases    int,  
    @c_firstorderkey  NVARCHAR(10),  
    @c_superorderflag  NVARCHAR(1),  
    @c_firsttime   NVARCHAR(1),  
    @c_logicalloc   NVARCHAR(18),  
    @c_Lottable01   NVARCHAR(18),  
    @c_Lottable02   NVARCHAR(18),  
    @c_Lottable03   NVARCHAR(18),  
    @d_Lottable04   datetime,  
    @d_Lottable05   datetime,  
    @n_PackPallet   int,  
    @n_PackCasecnt   int,  
    @n_pickslips_required int,    
    @dt_OrderDate     datetime,  
    @dt_DeliveryDate  datetime,  
      @c_OrderGroup        NVARCHAR(30),  
      @c_OrderTypeDescr    NVARCHAR(60)      
  
   DECLARE @n_Pallets  int,  
      @n_Cartons  int,  
      @n_Eaches  int,  
      @n_UOMQty  int  

   DECLARE @n_starttcnt INT
   SELECT  @n_starttcnt = @@TRANCOUNT

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   BEGIN TRAN  
  
   CREATE TABLE #temp_pick  
      ( PickSlipNo     NVARCHAR(10) NULL,  
      LoadKey          NVARCHAR(10),  
      OrderKey         NVARCHAR(10),  
      ExternOrderKey   NVARCHAR(50) NULL,    --tlting_ext
      ConsigneeKey     NVARCHAR(15),  
      C_Company        NVARCHAR(45),  
      C_Addr1          NVARCHAR(45) NULL,  
      C_Addr2          NVARCHAR(45) NULL,  
      C_Addr3          NVARCHAR(45) NULL,  
      C_Addr4          NVARCHAR(45) NULL,  
      C_Zip            NVARCHAR(18) NULL,  
      B_Company        NVARCHAR(45),  
      B_Addr1          NVARCHAR(45) NULL,  
      B_Addr2          NVARCHAR(45) NULL,  
      B_Addr3          NVARCHAR(45) NULL,  
      B_Addr4          NVARCHAR(45) NULL,  
      B_Zip            NVARCHAR(18) NULL,  
      Route            NVARCHAR(10) NULL,  
      RouteDescr       NVARCHAR(60) NULL,  -- RouteMaster.Descr  
      TrfRoom          NVARCHAR(5)  NULL,  -- LoadPlan.TrfRoom  
      Notes1           NVARCHAR(60) NULL,  
      Notes2           NVARCHAR(60) NULL,  
      LOC              NVARCHAR(10) NULL,  
      SKU              NVARCHAR(20),  
      SkuDescr         NVARCHAR(60),  
      Qty              int,  
      TempQty1       int,  
      TempQty2         int,  
      PrintedFlag      NVARCHAR(1) NULL,  
      Zone             NVARCHAR(1),  
      Lot          NVARCHAR(10),  
      Lottable01       NVARCHAR(18) NULL,  
      Lottable02       NVARCHAR(18) NULL,  
      Lottable03       NVARCHAR(18) NULL,  
      Lottable04       datetime NULL,  
      Lottable05       datetime NULL,  
      PackPallet      int,  
      PackCasecnt      int,  
      LogicalLoc       NVARCHAR(18) NULL,    
      OrderDate        datetime NULL,  
      DeliveryDate   datetime NULL,  
      Uom      NVARCHAR(10),  
      OrderGroup       NVARCHAR(20) NULL,  
      OrderTypeDescr   NVARCHAR(60) NULL )  
  
   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 8 - By Order  
   IF EXISTS(SELECT 1 FROM PICKHEADER (NOLOCK)   
              WHERE ExternOrderKey = @c_loadkey  
              AND   Zone = "3")  
   BEGIN  
      SELECT @c_firsttime = 'N'  
      SELECT @c_PrintedFlag = 'Y'  
   END  
   ELSE  
   BEGIN  
      SELECT @c_firsttime = 'Y'  
      SELECT @c_PrintedFlag = "N"  
   END -- Record Not Exists  
    
   INSERT INTO #TEMP_PICK  
      (PickSlipNo,         LoadKey,          OrderKey,         ExternOrderKey,  
      ConsigneeKey,    
      C_Company,           C_Addr1,          C_Addr2,          C_Addr3,  
      C_Addr4,             C_Zip,              
      B_Company,           B_Addr1,          B_Addr2,          B_Addr3,  
      B_Addr4,             B_Zip,              
      Route,            RouteDescr,  
      TrfRoom,             Notes1,           Notes2,           LOC,                
      SKU,                 SkuDescr,         Qty,             TempQty1,  
      TempQty2,          PrintedFlag,      Zone,               
      Lot,           Lottable01,       Lottable02,   Lottable03,  
      Lottable04,      Lottable05,       PackPallet,   PackCasecnt,    
      LogicalLoc,          OrderDate,        DeliveryDate,     UOM,  
      OrderGroup,       OrderTypeDescr )  
   SELECT (SELECT PickHeaderKey FROM PICKHEADER (NOLOCK)  
      WHERE ExternOrderKey = @c_loadKey  
      AND OrderKey = PickDetail.OrderKey  
      AND   Zone = '3'),    
    @c_loadKey as LoadKey,    
    PICKDETAIL.OrderKey,  
      ORDERS.ExternOrderKey,  
    ISNULL(ORDERS.BillToKey, '') AS ConsigneeKey,  
    ISNULL(ORDERS.C_Company, '') AS C_Company,  
    ISNULL(ORDERS.C_Address1, '') AS C_Addr1,  
    ISNULL(ORDERS.C_Address2, '') AS C_Addr2,        ISNULL(ORDERS.C_Address3, '') AS C_Addr3,     
    ISNULL(ORDERS.C_Address4, '') AS C_Addr4,     
    ISNULL(ORDERS.C_Zip, '') AS C_Zip,    
    ISNULL(ORDERS.B_Company, '') AS B_Company,  
    ISNULL(ORDERS.B_Address1, '') AS B_Addr1,  
    ISNULL(ORDERS.B_Address2, '') AS B_Addr2,    
    ISNULL(ORDERS.B_Address3, '') AS B_Addr3,     
    ISNULL(ORDERS.B_Address4, '') AS B_Addr4,    
    ISNULL(ORDERS.B_Zip, '') AS B_Zip,    
    ISNULL(ORDERS.Route, '') AS Route,    
    ISNULL(RouteMaster.Descr, '') RouteDescr,    
    ORDERS.Door AS TrfRoom,    
    CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes, '')) Notes1,    
    CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes2, '')) Notes2,    
    PICKDETAIL.Loc,    
    PICKDETAIL.Sku,    
    ISNULL(SKU.Descr, '') SkuDescr,    
    SUM(PICKDETAIL.qty) AS Qty,    
    CASE PICKDETAIL.UOM  
         WHEN '1' THEN PACK.Pallet     
         WHEN '2' THEN PACK.CaseCnt      
         WHEN '3' THEN PACK.InnerPack    
         ELSE 1  END AS UOMQty,    
    0 AS TempQty2,    
    ISNULL((SELECT DISTINCT 'Y' FROM PICKHEADER (NOLOCK) WHERE ExternOrderKey = @c_loadKey    
       AND Zone = '3'), 'N') AS PrintedFlag,    
    '3' Zone,    
    PICKDETAIL.Lot,    
    LOTATTRIBUTE.Lottable01,    
    LOTATTRIBUTE.Lottable02,    
    LOTATTRIBUTE.Lottable03,    
    ISNULL(LOTATTRIBUTE.Lottable04, '19000101') Lottable04,    
    ISNULL(LOTATTRIBUTE.Lottable05, '19000101') Lottable05,    
    PACK.Pallet,    
    PACK. CaseCnt,    
    ISNULL(LOC.LogicalLocation, '') AS LogicalLocation,    
    ISNULL(ORDERS.OrderDate, '19000101') AS OrderDate,  
    ISNULL(ORDERS.DeliveryDate, '19000101') AS DeliveryDate,  
      PACK.PackUOM3,  
      ORDERS.OrderGroup,  
      CODELKUP.Description AS OrderTypeDescr  
   FROM LOADPLANDETAIL (NOLOCK)   
      JOIN ORDERS (NOLOCK) ON (ORDERS.Orderkey = LOADPLANDETAIL.Orderkey)  
    JOIN ORDERDETAIL (NOLOCK) ON (ORDERDETAIL.Orderkey = LOADPLANDETAIL.Orderkey AND ORDERDETAIL.Loadkey = LOADPLANDETAIL.Loadkey)  
      JOIN STORER (NOLOCK) ON (ORDERS.StorerKey = STORER.StorerKey)  
      LEFT OUTER JOIN ROUTEMASTER ON (ROUTEMASTER.Route = ORDERS.Route)  
    JOIN PICKDETAIL (NOLOCK) ON (PICKDETAIL.OrderKey = ORDERDETAIL.Orderkey AND PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber )  
      JOIN LOTATTRIBUTE (NOLOCK) ON (PICKDETAIL.Lot = LOTATTRIBUTE.Lot)  
      JOIN SKU (NOLOCK)  ON (SKU.StorerKey = PICKDETAIL.StorerKey AND SKU.Sku = PICKDETAIL.Sku)  
      JOIN PACK (NOLOCK) ON (PICKDETAIL.Packkey = PACK.Packkey)  
      JOIN LOC (NOLOCK) ON (PICKDETAIL.LOC = LOC.LOC)  
      JOIN CODELKUP (NOLOCK) ON (CODELKUP.ListName = 'ORDERTYPE' AND CODELKUP.Code = ORDERS.Type)  
   WHERE PICKDETAIL.Status >= '0'    
   AND LOADPLANDETAIL.LoadKey = @c_loadKey  
   GROUP BY PICKDETAIL.OrderKey,     
   ORDERS.ExternOrderKey,                              
   ISNULL(ORDERS.BillToKey, ''),  
   ISNULL(ORDERS.c_Company, ''),     
   ISNULL(ORDERS.C_Address1,''),  
   ISNULL(ORDERS.C_Address2,''),  
   ISNULL(ORDERS.C_Address3,''),  
   ISNULL(ORDERS.C_Address4,''),  
   ISNULL(ORDERS.C_Zip,''),  
   ISNULL(ORDERS.B_Company, ''),     
   ISNULL(ORDERS.B_Address1,''),  
   ISNULL(ORDERS.B_Address2,''),  
   ISNULL(ORDERS.B_Address3,''),  
   ISNULL(ORDERS.B_Address4,''),  
   ISNULL(ORDERS.B_Zip,''),  
   ISNULL(ORDERS.Route,''),  
   ISNULL(ROUTEMASTER.Descr, ''),  
   ORDERS.Door,  
   CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes,  '')),                                      
   CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes2, '')),  
   PICKDETAIL.Loc,     
   PICKDETAIL.Sku,                           
   ISNULL(SKU.Descr,''),                    
   CASE PICKDETAIL.UOM  
       WHEN '1' THEN PACK.Pallet     
       WHEN '2' THEN PACK.CaseCnt      
       WHEN '3' THEN PACK.InnerPack    
       ELSE 1  END,  
   PICKDETAIL.Lot,                           
   LOTATTRIBUTE.Lottable01,                  
   LOTATTRIBUTE.Lottable02,                  
   LOTATTRIBUTE.Lottable03,                  
   ISNULL(LOTATTRIBUTE.Lottable04, '19000101'),          
   ISNULL(LOTATTRIBUTE.Lottable05, '19000101'),          
   PACK.Pallet,  
   PACK.CaseCnt,  
   ISNULL(LOC.LogicalLocation, ''),    
   ISNULL(ORDERS.OrderDate, '19000101'),  
   ISNULL(ORDERS.DeliveryDate, '19000101'),  
   PACK.PackUOM3,  
   ORDERS.OrderGroup,  
   CODELKUP.Description  
    
   BEGIN TRAN  
     
   -- Uses PickType as a Printed Flag  
   UPDATE PICKHEADER  
   SET PickType = '1',  
     TrafficCop = NULL  
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
     -- SELECT @c_PrintedFlag = "Y"  
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
  
   SELECT @n_pickslips_required = Count(DISTINCT OrderKey)   
   FROM #TEMP_PICK  
   WHERE PickSlipNo IS NULL  
   IF @@ERROR <> 0  
   BEGIN  
      GOTO FAILURE  
   END  
   ELSE IF @n_pickslips_required > 0  
   BEGIN  
      BEGIN TRAN
      EXECUTE nspg_GetKey 'PICKSLIP', 9, @c_pickheaderkey OUTPUT, @b_success OUTPUT, @n_err  OUTPUT, @c_errmsg OUTPUT, 0, @n_pickslips_required  
      COMMIT TRAN

      BEGIN TRAN
      INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)  
          SELECT 'P' + RIGHT ( REPLICATE ('0', 9) +   
          dbo.fnc_LTrim( dbo.fnc_RTrim(  
             STR(   
                CAST(@c_pickheaderkey AS INT) + ( SELECT COUNT(DISTINCT orderkey)   
                                                  FROM #TEMP_PICK AS Rank   
                                                  WHERE Rank.OrderKey < #TEMP_PICK.OrderKey )   
                 ) -- str  
                 )) -- dbo.fnc_RTrim  
              , 9)   
           , OrderKey, LoadKey, '0', '3', ''  
          FROM #TEMP_PICK WHERE PickSlipNo IS NULL  
          GROUP By LoadKey, OrderKey  
     
      UPDATE #TEMP_PICK   
      SET PickSlipNo = PICKHEADER.PickHeaderKey  
      FROM PICKHEADER (NOLOCK)  
      WHERE PICKHEADER.ExternOrderKey = #TEMP_PICK.LoadKey  
      AND   PICKHEADER.OrderKey = #TEMP_PICK.OrderKey  
      AND   PICKHEADER.Zone = '3'  
      AND   #TEMP_PICK.PickSlipNo IS NULL  
     
      UPDATE PICKDETAIL  
      SET PickSlipNo = #TEMP_PICK.PickSlipNo,  
          TrafficCop = NULL  
      FROM #TEMP_PICK   
      WHERE #TEMP_PICK .OrderKey = PICKDETAIL.OrderKey  
      AND   PICKDETAIL.PickSlipNo IS NULL  

      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END
   END  
   GOTO SUCCESS  
  
 FAILURE:  
     DELETE FROM #TEMP_PICK  
 SUCCESS:  
     SELECT * FROM #TEMP_PICK    
     DROP TABLE #TEMP_PICK    

   WHILE @@TRANCOUNT < @n_starttcnt
   BEGIN
      BEGIN TRAN
   END   
END  


GO