SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/        
/* Stored Procedure: isp_RPT_LP_PLISTN_050                              */        
/* CreatiON Date: 16-JUN-2023                                           */    
/* Copyright: Maersk                                                    */    
/* Written by: WZPang                                                   */    
/*                                                                      */    
/* Purpose: WMS-22778 (DU)                                              */      
/*                                                                      */        
/* Called By: RPT_LP_PLISTN_050            									   */        
/*                                                                      */        
/* PVCS VersiON: 1.2                                                    */        
/*                                                                      */        
/* VersiON: 7.0                                                         */        
/*                                                                      */        
/* Data ModificatiONs:                                                  */        
/*                                                                      */        
/* Updates:                                                             */        
/* Date         Author   Ver  Purposes                                  */
/* 16-JUN-2023  WZPang   1.0  DevOps Combine Script                     */
/* 27-SEP-2023  WZPang   1.1  Edit Columns (WZ01)                       */
/* 31-Oct-2023  WLChooi  1.2  UWP-10213 - Global Timezone (GTZ01)       */
/************************************************************************/        
CREATE   PROC [dbo].[isp_RPT_LP_PLISTN_050] (
      @c_Loadkey NVARCHAR(10)    
)        
 AS        
 BEGIN        
            
   SET NOCOUNT ON        
   SET ANSI_NULLS ON        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
   SET ANSI_WARNINGS ON        

   DECLARE @c_pickheaderkey        NVARCHAR(10),  
           @n_continue             INT,  
           @c_errmsg               NVARCHAR(255),  
           @b_success              INT,  
           @n_err                  INT,  
           @n_pickslips_required   INT 
         , @n_SortByNotesCustOrd   INT  
         , @n_ShowCustOrderBarCode INT  
         , @c_Storerkey            NVARCHAR(15)   
         , @n_starttcnt            INT   
         , @c_Facility             NVARCHAR(5)   --GTZ01
  
   SELECT @n_starttcnt = @@TRANCOUNT     
   SELECT @n_pickslips_required = 0      
  
   WHILE @@TRANCOUNT > 0   
   BEGIN  
      COMMIT TRAN  
   END  
  
   CREATE TABLE #TEMP_PICK  
       ( PickSlipNo       NVARCHAR(10) NULL,  
         LoadKey          NVARCHAR(10),  
         OrderKey         NVARCHAR(10),  
         ConsigneeKey     NVARCHAR(15),  
         Company          NVARCHAR(45),  
         Addr1            NVARCHAR(45) NULL,  
         Addr2            NVARCHAR(45) NULL,  
         Addr3            NVARCHAR(45) NULL,  
         PostCode         NVARCHAR(15) NULL,  
         Route            NVARCHAR(10) NULL,  
         Route_Desc       NVARCHAR(60) NULL, -- RouteMaster.Desc  
         TrfRoom          NVARCHAR(5)  NULL, -- LoadPlan.TrfRoom  
         Notes1           NVARCHAR(60) NULL,  
         Notes2           NVARCHAR(60) NULL,  
         LOC              NVARCHAR(10) NULL,  
         SKU              NVARCHAR(20),  
         SkuDesc          NVARCHAR(60),  
         Qty              INT,  
         TempQty1         INT NULL,  
         TempQty2         INT,  
         PrintedFlag      NVARCHAR(1) NULL,  
         Zone             NVARCHAR(1),  
         PgGroup          INT,  
         RowNum           INT,  
         Lot              NVARCHAR(10),  
         Carrierkey       NVARCHAR(60) NULL,  
         VehicleNo        NVARCHAR(10) NULL,  
         Lottable02       NVARCHAR(10) NULL,  
         Lottable04       datetime NULL,  
         Lottable05       datetime NULL,  
         packpallet       INT,  
         packcasecnt      INT,  
         externorderkey   NVARCHAR(50) NULL, 
         LogicalLoc       NVARCHAR(18) NULL, 
         Areakey          NVARCHAR(10) NULL,   
         UOM              NVARCHAR(10) NULL,  
         DeliveryDate     NVARCHAR(10) NULL, 
         Lottable03       NVARCHAR(18) NULL, 
         Lottable01       NVARCHAR(18) NULL, 
         Altsku           NVARCHAR(20) NULL,
         StdCube          FLOAT,
         SKUWeight        FLOAT) 
  
   INSERT INTO #TEMP_PICK  
         (PickSlipNo,          LoadKey,          OrderKey,         ConsigneeKey,  
          Company,             Addr1,            Addr2,            PgGroup,  
          Addr3,               PostCode,         Route,  
          Route_Desc,          TrfRoom,          Notes1,           RowNum,  
          Notes2,              LOC,              SKU,  
          SkuDesc,             Qty,              TempQty1,  
          TempQty2,            PrintedFlag,      Zone,  
          Lot,                 CarrierKey,       VehicleNo,        Lottable02,  
          Lottable04,          Lottable05,       packpallet,       packcasecnt,  
          externorderkey,      LogicalLoc,       Areakey,          DeliveryDate,  
          Lottable03,          Lottable01,       Altsku,           StdCube,
          SKUWeight)   
  
   SELECT DISTINCT  
         (SELECT PICKHEADERKEY FROM PICKHEADER (NOLOCK)  
          WHERE ExternOrderKey = @c_LoadKey  
          AND OrderKey = Orders.OrderKey  
          AND ZONE = '3'),  
         @c_LoadKey AS LoadKey,  
         Orders.OrderKey,  
         -- SOS82873 Change company info FROM MBOL level to LOAD level  
         -- NOTE: In ECCO case,2 style, the English information saved in C_company, C_Address?nd Chinese Information saved in B_company,B_Address  
         (CASE WHEN StorerConfig.sValue = '1' THEN ISNULL(Orders.CONSIGNEEKEY , '')  
         ELSE ISNULL(Orders.BillToKey , '')  END  ) AS ConsigneeKey ,  
         (CASE WHEN StorerConfig.sValue = '1' THEN ISNULL(Orders.B_Company , '')  
         ELSE ISNULL(Orders.C_Company, '')  END  ) AS Company  ,  
         (CASE WHEN StorerConfig.sValue = '1' THEN ISNULL(Orders.B_Address1 , '')  
         ELSE ISNULL(Orders.C_Address1, '')  END  ) AS Addr1  ,  
         (CASE WHEN StorerConfig.sValue = '1' THEN ISNULL(Orders.B_Address2 , '')  
         ELSE ISNULL(Orders.C_Address2, '')  END  ) AS Addr2  ,  
         0 AS PgGroup,  
         (CASE WHEN StorerConfig.sValue = '1' THEN ISNULL(Orders.B_Address3 , '')  
         ELSE ISNULL(Orders.C_Address3, '')  END  ) AS Addr3,  
         ISNULL(Orders.C_Zip,'') AS PostCode,  
         ISNULL(Orders.Route,'') AS Route,  
         ISNULL(RouteMaster.Descr, '') Route_Desc,  
         Orders.Door AS TrfRoom,  
         CONVERT(NVARCHAR(60), ISNULL(Orders.Notes,  '')) Notes1,  
         0 AS RowNo,  
         CONVERT(NVARCHAR(60), ISNULL(Orders.Notes2, '')) Notes2,  
         PickDetail.loc,  
         PickDetail.sku,  
         ISNULL(Sku.Descr,'') SkuDescr,  
         SUM(PickDetail.qty) AS Qty,  
         0 AS TEMPQTY1,  
         TempQty2 =  
            CASE WHEN pack.pallet = 0 then 0  
                 ELSE CASE WHEN (Sum(pickdetail.qty) % CAST(pack.pallet AS INT)) > 0 THEN 0  
                           ELSE 1 END  
            END ,  
         ISNULL((SELECT DISTINCT 'Y' FROM PickHeader (NOLOCK) WHERE ExternOrderKey = @c_LoadKey AND Zone = '3'), 'N') AS PrintedFlag,  
         '3' Zone,  
         --Pickdetail.Lot,  --WZ01
         '' AS Lot,         --WZ01
         '' CarrierKey,  
         '' AS VehicleNo,  
         --SUBSTRING(LotAttribute.Lottable02, 1,10),                --WZ01
         --ISNULL(LotAttribute.Lottable04, '19000101') Lottable04,  --WZ01 
         --ISNULL(LotAttribute.Lottable05, '19000101') Lottable05,  --WZ01
         '' AS Lottable02,
         '19000101' AS Lottable04,
         '19000101' AS Lottable05,
         PACK.Pallet,  
         PACK.CaseCnt,  
         Orders.ExternOrderKey AS ExternOrderKey,  
         ISNULL(LOC.LogicalLocation, '') AS LogicalLocation,  
         ISNULL(AreaDetail.AreaKey, '00') AS Areakey,               
         ISNULL(CONVERT(NVARCHAR(10), [dbo].[fnc_ConvSFTimeZone](Orders.StorerKey, Orders.Facility, Orders.DeliveryDate), 103), ''),   --GTZ01  
         SUBSTRING(LotAttribute.Lottable03, 1, 18), 
         --SUBSTRING(LotAttribute.Lottable01, 1, 18),               --WZ01 
         '' AS Lottable01,                                          --WZ01
         CASE WHEN ISNULL(SC.Svalue,'0') = '1' THEN  
              Sku.Altsku  
         ELSE 'NOSHOW' END AS ALTSKU,
         SKU.STDCUBE,
         SKU.Weight
   FROM LoadPlanDetail (NOLOCK)  
   JOIN Orders (NOLOCK) ON (Orders.Orderkey = LoadPlanDetail.Orderkey)  
   JOIN Storer (NOLOCK) ON (Orders.StorerKey = Storer.StorerKey)  
   JOIN OrderDetail (NOLOCK) ON (OrderDetail.OrderKey = Orders.OrderKey)       
   LEFT OUTER JOIN StorerConfig ON (Orders.StorerKey = StorerConfig.StorerKey AND StorerConfig.ConfigKey = 'UsedBillToAddressForPickSlip')  
   LEFT OUTER JOIN RouteMaster ON (RouteMaster.Route = Orders.Route)  
   JOIN PickDetail (NOLOCK) ON (PickDetail.OrderKey = LoadPlanDetail.OrderKey  
                   AND Orders.Orderkey = PICKDETAIL.Orderkey  
                   AND ORDERDETAIL.Orderlinenumber = PICKDETAIL.Orderlinenumber)  
   JOIN LotAttribute (NOLOCK) ON (PickDetail.Lot = LotAttribute.Lot)  
   JOIN Sku (NOLOCK)  ON (Sku.StorerKey = PickDetail.StorerKey AND Sku.Sku = PickDetail.Sku AND SKU.Sku = OrderDetail.Sku)  
   JOIN PACK (NOLOCK) ON (SKU.Packkey = PACK.Packkey)  
   JOIN LOC WITH (NOLOCK, INDEX (PKLOC)) ON (LOC.LOC = PICKDETAIL.LOC)  
   LEFT OUTER JOIN AreaDetail (NOLOCK) ON (LOC.PutawayZone = AreaDetail.PutawayZone)  
   LEFT OUTER JOIN StorerConfig SC (NOLOCK) ON (Orders.Storerkey = SC.Storerkey AND SC.Configkey = 'PICKORD01_SHOWALTSKU')    
   WHERE PickDetail.Status >= '0' AND LoadPlanDetail.LoadKey = @c_LoadKey  
   GROUP BY Orders.OrderKey,  
            StorerConfig.sValue,  
            Orders.CONSIGNEEKEY,  
            Orders.B_Company,  
            Orders.B_Address1,  
            Orders.B_Address2,  
            Orders.B_Address3,  
            Orders.BillToKey,  
            Orders.C_Company,  
            Orders.C_Address1,  
            Orders.C_Address2,  
            Orders.C_Address3,  
            ISNULL(Orders.C_Zip,''),  
            ISNULL(Orders.Route,''),  
            ISNULL(RouteMaster.Descr, ''),  
            Orders.Door,  
            CONVERT(NVARCHAR(60), ISNULL(Orders.Notes, '')),  
            CONVERT(NVARCHAR(60), ISNULL(Orders.Notes2, '')),  
            PickDetail.Loc,  
            PickDetail.Sku,  
            ISNULL(Sku.Descr,''),  
            --Pickdetail.Lot,                               --WZ01
            --SUBSTRING(LotAttribute.Lottable02, 1, 10),    --WZ01
            --ISNULL(LotAttribute.Lottable02,''),           --WZ01
            --ISNULL(LotAttribute.Lottable04, '19000101'),  --WZ01
            --ISNULL(LotAttribute.Lottable05, '19000101'),  --WZ01
            PACK.Pallet,  
            PACK.CaseCnt,  
            Orders.ExternOrderKey,  
            ISNULL(LOC.LogicalLocation, ''),  
            ISNULL(AreaDetail.AreaKey, '00'),      
            ISNULL(CONVERT(NVARCHAR(10), [dbo].[fnc_ConvSFTimeZone](Orders.StorerKey, Orders.Facility, Orders.DeliveryDate), 103), ''),   --GTZ01    
            SUBSTRING(LotAttribute.Lottable03, 1, 18), 
            --ISNULL(LotAttribute.Lottable01, ''),          --WZ01
            CASE WHEN ISNULL(SC.Svalue,'0') = '1' THEN 
                 Sku.Altsku  
            ELSE 'NOSHOW' END  ,
            SKU.STDCUBE,
            SKU.Weight
  
   BEGIN TRAN  
   -- Uses PickType AS a Printed Flag  
   UPDATE PickHeader SET PickType = '1', TrafficCop = NULL  
   WHERE ExternOrderKey = @c_LoadKey  
   AND Zone = '3'  
  
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
  
   SELECT @n_pickslips_required = COUNT(DISTINCT OrderKey)  
   FROM #TEMP_PICK  
   WHERE ISNULL(RTRIM(PickSlipNo),'') = ''   
  
   IF @@ERROR <> 0  
   BEGIN  
      GOTO FAILURE  
   END  
   ELSE IF @n_pickslips_required > 0  
   BEGIN  
      BEGIN TRAN 
      EXECUTE nspg_GetKey 'PICKSLIP', 9, @c_pickheaderkey OUTPUT, @b_success OUTPUT, @n_err  OUTPUT, @c_errmsg OUTPUT, 0, @n_pickslips_required  
  
      SELECT @n_err = @@ERROR  
      IF @n_err = 0  
      BEGIN  
         WHILE @@TRANCOUNT > 0  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
  
      BEGIN TRAN   
      INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)  
      SELECT 'P' + RIGHT ( REPLICATE ('0', 9) +  
                           dbo.fnc_LTrim( dbo.fnc_RTrim( STR( CAST(@c_pickheaderkey AS INT) +  
                           ( SELECT COUNT(DISTINCT orderkey)  
                             FROM #TEMP_PICK AS Rank  
                             WHERE Rank.OrderKey < #TEMP_PICK.OrderKey  
                             AND ISNULL(RTRIM(Rank.PickSlipNo),'') = '' )
                           ) -- str  
                          )) -- dbo.fnc_RTrim  
                        , 9)  
            , OrderKey, LoadKey, '0', '3', ''  
      FROM #TEMP_PICK WHERE ISNULL(RTRIM(PickSlipNo),'') = ''   
      GROUP By LoadKey, OrderKey  
  
      SELECT @n_err = @@ERROR 
      IF @n_err = 0  
      BEGIN  
         WHILE @@TRANCOUNT > 0  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
  
      UPDATE #TEMP_PICK  
      SET PickSlipNo = PICKHEADER.PickHeaderKey  
      FROM PICKHEADER (NOLOCK)  
      WHERE PICKHEADER.ExternOrderKey = #TEMP_PICK.LoadKey  
      AND   PICKHEADER.OrderKey = #TEMP_PICK.OrderKey  
      AND   PICKHEADER.Zone = '3'  
      AND   ISNULL(RTRIM(#TEMP_PICK.PickSlipNo),'') = '' 
   END  
   GOTO SUCCESS  
  
   FAILURE:  
      DELETE FROM #TEMP_PICK  
  
   SUCCESS:  
      SET @c_Storerkey = ''  
      SELECT TOP 1 @c_Storerkey = Orders.Storerkey  
                 , @c_Facility = Orders.Facility   --GTZ01
      FROM LoadPlanDetail WITH (NOLOCK)  
      JOIN Orders WITH (NOLOCK) ON (LoadPlanDetail.Orderkey = Orders.Orderkey)  
      WHERE LoadPlanDetail.Loadkey = @c_LoadKey  
      ORDER BY LoadPlanDetail.LoadLineNumber  
  
      SET @n_SortByNotesCustOrd   = 0  
      SET @n_ShowCustOrderBarCode = 0  
      SELECT @n_SortByNotesCustOrd   = MAX(CASE WHEN CODE = 'SortByNotesCustOrd'   THEN 1 ELSE 0 END)  
           , @n_ShowCustOrderBarCode = MAX(CASE WHEN CODE = 'ShowCustOrderBarCode' THEN 1 ELSE 0 END)  
      FROM CODELKUP WITH (NOLOCK)  
      WHERE ListName = 'PICKORD01'  
      AND   Storerkey= @c_Storerkey  
  
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
           , SUM(Qty) AS Qty      --WZ01
           , TempQty1  
           , TempQty2  
           , PrintedFlag  
           , Zone  
           , PgGroup  
           , RowNum  
           , Lot  
           , Carrierkey  
           , VehicleNo  
           , Lottable02  
           , [dbo].[fnc_ConvSFTimeZone](@c_Storerkey, @c_Facility, Lottable04) AS Lottable04   --GTZ01
           , [dbo].[fnc_ConvSFTimeZone](@c_Storerkey, @c_Facility, Lottable05) AS Lottable05   --GTZ01  
           , packpallet  
           , packcasecnt  
           , externorderkey  
           , LogicalLoc  
           , Areakey  
           , UOM  
           , DeliveryDate
           , Lottable03  
           , Lottable01  
           , Altsku  
           , CASE WHEN @n_ShowCustOrderBarCode = 1 THEN ExternOrderkey ELSE '' END   AS ExternOrderkey_bc
           , StdCube
           , SKUWeight
           , [dbo].[fnc_ConvSFTimeZone](@c_Storerkey, @c_Facility, GETDATE()) AS CurrentDateTime   --GTZ01
      FROM #TEMP_PICK 
      --(WZ01) Start
      GROUP BY PickSlipNo     
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
           , TempQty1  
           , TempQty2  
           , PrintedFlag  
           , Zone  
           , PgGroup  
           , RowNum  
           , Lot  
           , Carrierkey  
           , VehicleNo  
           , Lottable02  
           , Lottable04  
           , Lottable05  
           , packpallet  
           , packcasecnt  
           , externorderkey  
           , LogicalLoc  
           , Areakey  
           , UOM  
           , DeliveryDate  
           , Lottable03  
           , Lottable01  
           , Altsku  
           , CASE WHEN @n_ShowCustOrderBarCode = 1 THEN ExternOrderkey ELSE '' END
           , StdCube
           , SKUWeight
      --(WZ01) End
      ORDER BY CASE WHEN @n_SortByNotesCustOrd = 1 THEN Notes1 + Notes2 ELSE '' END  
             , CASE WHEN @n_SortByNotesCustOrd = 1 THEN ExternOrderkey  ELSE '' END  
             , Company  
             , OrderKey  
             , Areakey  
             , TempQty2 DESC  
             , LogicalLoc  
             , Loc  
             , SKU  
             , Lottable02  
             , UOM  
   DROP Table #TEMP_PICK   
   

END -- procedure    

GO