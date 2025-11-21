SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_GetPickSlipOrders121                           */
/* Creation Date: 2021-04-09                                            */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-16783 - ID-CR-PickingSlip RCM Report for IDSMED         */
/*          Copy from nsp_GetPickSlipOrders05 and modify                */
/*                                                                      */
/* Input Parameters:  @c_loadkey  - Loadkey                             */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_print_pickorder121                 */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author    Ver.  Purposes                                 */
/* 31-May-2021 Mingle    1.1   Add orders.ordergroup                    */
/************************************************************************/

CREATE PROC [dbo].[isp_GetPickSlipOrders121] (@c_loadkey NVARCHAR(10)) 
 AS
 BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @c_pickheaderkey  NVARCHAR(10),
           @n_continue            INT,
           @c_errmsg              NVARCHAR(255),
           @b_success             INT,
           @n_err                 INT,
           @c_sku                 NVARCHAR(20),
           @n_qty                 INT,
           @c_loc                 NVARCHAR(10),
           @n_cases               INT,
           @n_perpallet           INT,
           @c_storer              NVARCHAR(15),
           @c_orderkey            NVARCHAR(10),
           @c_ConsigneeKey        NVARCHAR(15),
           @c_Company             NVARCHAR(45),
           @c_Addr1               NVARCHAR(45),
           @c_Addr2               NVARCHAR(45),
           @c_Addr3               NVARCHAR(45),
           @c_PostCode            NVARCHAR(15),
           @c_Route               NVARCHAR(10),
           @c_Route_Desc          NVARCHAR(60), -- RouteMaster.Desc
           @c_TrfRoom             NVARCHAR(5),  -- LoadPlan.TrfRoom
           @c_Notes1              NVARCHAR(60),
           @c_Notes2              NVARCHAR(60),
           @c_SkuDesc             NVARCHAR(60),
           @n_CaseCnt             INT,
           @n_PalletCnt           INT,
           @c_ReceiptTm           NVARCHAR(20),
           @c_PrintedFlag         NVARCHAR(1),
           @c_UOM                 NVARCHAR(10),
           @n_UOM3                INT,
           @c_Lot                 NVARCHAR(10),
           @c_StorerKey           NVARCHAR(15),
           @c_Zone                NVARCHAR(1),
           @n_PgGroup             INT,
           @n_TotCases            INT,
           @n_RowNo               INT,
           @c_PrevSKU             NVARCHAR(20),
           @n_SKUCount            INT,
           @c_Carrierkey          NVARCHAR(60),
           @c_VehicleNo           NVARCHAR(10),
           @c_firstorderkey       NVARCHAR(10),
           @c_superorderflag      NVARCHAR(1),
           @c_firsttime           NVARCHAR(1),
           @c_logicalloc          NVARCHAR(18),
           @c_Lottable02          NVARCHAR(18),  
           @d_Lottable04          DATETIME,
           @n_packpallet          INT,
           @n_packcasecnt         INT,
           @c_externorderkey      NVARCHAR(50),  
           @n_pickslips_required  INT,  
           @c_areakey             NVARCHAR(10),
           @c_dischargeplace      NVARCHAR(30),  
           @c_invoiceno           NVARCHAR(20),  
           @c_Addr4               NVARCHAR(45),  
           @c_City                NVARCHAR(45)   
                           
   DECLARE @c_PrevOrderKey NVARCHAR(10),
           @n_Pallets      INT,
           @n_Cartons      INT,
           @n_Eaches       INT,
           @n_UOMQty       INT

   SET @n_Continue = 1
    
   DECLARE @c_udf01 NVARCHAR(60),
           @c_udf02 NVARCHAR(60),
           @c_udf03 NVARCHAR(60),
           @c_TableName NVARCHAR(100),
           @c_ColName NVARCHAR(100),
           @c_ColType NVARCHAR(100),
           @c_ISCombineSKU NCHAR(1),
           @cSQL NVARCHAR(Max),
           @c_FromWhere NVARCHAR(2000),              
           @c_InsertSelect NVARCHAR(2000)                        
            
   SET @c_ISCombineSKU = 'N'
              
   CREATE TABLE #TEMP_SKU (Storerkey NVARCHAR(15) NULL, SKU NVARCHAR(20) NULL, DESCR NVARCHAR(60) NULL, COMBINESKU NVARCHAR(100) NULL)
   
   SELECT TOP 1 @c_Storer = Storerkey
   FROM ORDERS (NOLOCK)
   WHERE Loadkey = @c_Loadkey
      
   SELECT @c_udf01 = ISNULL(CL.UDF01,''),
          @c_udf02 = ISNULL(CL.UDF02,''),
          @c_udf03 = ISNULL(CL.UDF03,'')
   FROM CODELKUP CL (NOLOCK)
   WHERE Listname = 'COMBINESKU'
   AND Code = 'CONCATENATESKU'
   AND Storerkey = @c_Storer
   
   IF @@ROWCOUNT > 0
   BEGIN
      SET @c_ISCombineSKU = 'Y'
      SET @c_InsertSelect = ' INSERT INTO #TEMP_SKU SELECT DISTINCT SKU.Storerkey, SKU.Sku, SKU.Descr '
      SET @c_FromWhere = ' FROM SKU (NOLOCK) '
                       + ' JOIN ORDERDETAIL OD (NOLOCK) ON SKU.Storerkey = OD.Storerkey AND SKU.Sku = OD.Sku '
                       + ' JOIN ORDERS O (NOLOCK) ON OD.Orderkey = O.Orderkey '
                       + ' WHERE O.Loadkey = RTRIM(@c_Loadkey) '
      
      --UDF01
      SET @c_ColName = @c_udf01
      SET @c_TableName = 'SKU'
      IF CharIndex('.', @c_udf01) > 0
      BEGIN
         SET @c_TableName = LEFT(@c_udf01, CharIndex('.', @c_udf01) - 1)
         SET @c_ColName   = SUBSTRING(@c_udf01, CharIndex('.', @c_udf01) + 1, LEN(@c_udf01) - CharIndex('.', @c_udf01))
      END
      
      SET @c_ColType = ''
      SELECT @c_ColType = DATA_TYPE 
      FROM   INFORMATION_SCHEMA.COLUMNS WITH (NOLOCK)
      WHERE  TABLE_NAME = @c_TableName
      AND    COLUMN_NAME = @c_ColName
      
      IF @c_ColType IN ('char', 'nvarchar', 'varchar') AND @c_TableName = 'SKU'
           SELECT @c_InsertSelect = @c_InsertSelect + ',LTRIM(RTRIM(ISNULL('+ RTRIM(@c_udf01) + ',''''))) '                                        
      ELSE
          SELECT @c_InsertSelect = @c_InsertSelect + ',''' + LTRIM(RTRIM(@c_udf01)) + ''' '                                    
      
      --UDF02
      SET @c_ColName = @c_udf02
      SET @c_TableName = 'SKU'
      IF CharIndex('.', @c_udf02) > 0
      BEGIN
         SET @c_TableName = LEFT(@c_udf02, CharIndex('.', @c_udf02) - 1)
         SET @c_ColName   = SUBSTRING(@c_udf02, CharIndex('.', @c_udf02) + 1, LEN(@c_udf02) - CharIndex('.', @c_udf02))
      END
      
      SET @c_ColType = ''
      SELECT @c_ColType = DATA_TYPE 
      FROM   INFORMATION_SCHEMA.COLUMNS WITH (NOLOCK) 
      WHERE  TABLE_NAME = @c_TableName
      AND    COLUMN_NAME = @c_ColName
      
      IF @c_ColType IN ('char', 'nvarchar', 'varchar') AND @c_TableName = 'SKU'
           SELECT @c_InsertSelect = @c_InsertSelect + ' + LTRIM(RTRIM(ISNULL('+ RTRIM(@c_udf02) + ',''''))) '                                        
      ELSE
           SELECT @c_InsertSelect = @c_InsertSelect + ' + ''' + LTRIM(RTRIM(@c_udf02)) + ''' '                                    
      
      --UDF03
      SET @c_ColName = @c_udf03
      SET @c_TableName = 'SKU'
      IF CharIndex('.', @c_udf03) > 0
      BEGIN
         SET @c_TableName = LEFT(@c_udf03, CharIndex('.', @c_udf03) - 1)
         SET @c_ColName   = SUBSTRING(@c_udf03, CharIndex('.', @c_udf03) + 1, LEN(@c_udf03) - CharIndex('.', @c_udf03))
      END
      
      SET @c_ColType = ''
      SELECT @c_ColType = DATA_TYPE 
      FROM   INFORMATION_SCHEMA.COLUMNS WITH (NOLOCK) 
      WHERE  TABLE_NAME = @c_TableName
      AND    COLUMN_NAME = @c_ColName
      
      IF @c_ColType IN ('char', 'nvarchar', 'varchar') AND @c_TableName = 'SKU'
           SELECT @c_InsertSelect = @c_InsertSelect + ' + LTRIM(RTRIM(ISNULL('+ RTRIM(@c_udf03) + ',''''))) '                                        
      ELSE
           SELECT @c_InsertSelect = @c_InsertSelect + ' + ''' + LTRIM(RTRIM(@c_udf03)) + ''' '                                                  
      
      SET @cSQL = @c_InsertSelect + @c_FromWhere
      
      -- tlting
      EXEC sp_executesql @cSQL, N'@c_Loadkey NVARCHAR(10)'  , @c_Loadkey          
   END
   
   IF @c_ISCombineSKU = 'N'
   BEGIN
      INSERT INTO #TEMP_SKU
      SELECT DISTINCT SKU.Storerkey, SKU.Sku, SKU.Descr, SKU.Sku
      FROM SKU (NOLOCK)
      JOIN ORDERDETAIL OD (NOLOCK) ON SKU.Storerkey = OD.Storerkey AND SKU.Sku = OD.Sku
      JOIN ORDERS O (NOLOCK) ON OD.Orderkey = O.Orderkey
      WHERE O.Loadkey = @c_Loadkey
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
     Route_Desc       NVARCHAR(60) NULL,
     TrfRoom          NVARCHAR(5)  NULL, 
     Notes1           NVARCHAR(60) NULL,
     Notes2           NVARCHAR(60) NULL,
     LOC              NVARCHAR(10) NULL,
     ID               NVARCHAR(18) NULL,
     SKU              NVARCHAR(20),
     SkuDesc          NVARCHAR(60),
     Qty              INT,
     TempQty1         INT,
     TempQty2         INT,
     PrintedFlag      NVARCHAR(1) NULL,
     Zone             NVARCHAR(1),
     PgGroup          INT,
     RowNum           INT,
     Lot              NVARCHAR(10),
     Carrierkey       NVARCHAR(60) NULL,
     VehicleNo        NVARCHAR(10) NULL,
     Lottable02       NVARCHAR(18) NULL,
     Lottable04       DATETIME NULL,
     packpallet       INT,
     packcasecnt      INT, 
     packinner        INT,              
     packeaches       INT,              
     externorderkey   NVARCHAR(50) NULL,
     LogicalLoc       NVARCHAR(18) NULL,
     Areakey          NVARCHAR(10) NULL,
     UOM              NVARCHAR(10),     
     Pallet_cal       INT,  
     Cartons_cal      INT,  
     inner_cal        INT,              
     Each_cal         INT,  
     Total_cal        INT,              
     DeliveryDate     DATETIME NULL,
     Lottable01       NVARCHAR(18) NULL,
     Lottable10       NVARCHAR(30) NULL,
     Lottable05       DATETIME NULL,    
     DischargePlace   NVARCHAR(30) NULL,
     InvoiceNo        NVARCHAR(20) NULL,
     Pltcnt           INT NULL,    
     Addr4            NVARCHAR(45),
     City             NVARCHAR(45), 
     Storerkey        NVARCHAR(15), 
     showbarcode      NVARCHAR(1),  
     showcontactphone NVARCHAR(1),  
     c_contact1       NVARCHAR(45),
     c_phone1         NVARCHAR(45),
     UPC              NVARCHAR(255),
     SNotes1          NVARCHAR(255),
     Lottable08       NVARCHAR(30) NULL,
     Ordergroup       NVARCHAR(30)     --ML01
   )
   INSERT INTO #TEMP_PICK (
      PickSlipNo,          LoadKey,         OrderKey,         ConsigneeKey,
      Company,             Addr1,           Addr2,            PgGroup,
      Addr3,               PostCode,        [Route],
      Route_Desc,          TrfRoom,         Notes1,           RowNum,
      Notes2,              LOC,             ID,               SKU,
      SkuDesc,             Qty,             TempQty1,
      TempQty2,            PrintedFlag,     [Zone],
      Lot,                 CarrierKey,      VehicleNo,        Lottable02,
      Lottable04,          packpallet,      packcasecnt,      packinner,     
      packeaches,          externorderkey,  LogicalLoc,       Areakey,          UOM,  
      Pallet_cal,          Cartons_cal,     inner_cal,        Each_cal,         Total_cal,  
      DeliveryDate,        Lottable01,      Lottable10,       Lottable05 ,
      DischargePlace,      InvoiceNo,       Addr4,            City, 
      Storerkey,           showbarcode,     showcontactphone, c_contact1,       c_phone1,
      UPC,                 SNotes1,         Lottable08,       Ordergroup     --ML01
   )
   SELECT
      (SELECT PICKHEADERKEY FROM PICKHEADER WITH (NOLOCK)
       WHERE ExternOrderKey = @c_LoadKey 
       AND OrderKey = PickDetail.OrderKey 
       AND ZONE = '3'),
      @c_LoadKey as LoadKey,                 
      PickDetail.OrderKey,                            
      ISNULL(ORDERS.ConsigneeKey, '') AS ConsigneeKey,  
      ISNULL(ORDERS.c_Company, '')  AS Company,   
      ISNULL(ORDERS.C_Address1,'') AS Addr1,            
      ISNULL(ORDERS.C_Address2,'')  AS Addr2,
      0 AS PgGroup,                              
      ISNULL(ORDERS.C_Address3,'') AS Addr3,            
      ISNULL(ORDERS.C_Zip,'') AS PostCode,
      ISNULL(ORDERS.[Route],'') AS [ROUTE],         
      ISNULL(RouteMaster.Descr, '') Route_Desc,       
      ORDERS.Door AS TrfRoom,
      CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes,  '')) Notes1,                                    
      0 AS RowNo, 
      CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes2, '')) Notes2,
      PickDetail.loc,   
      PickDetail.id,            
      CASE WHEN ISNULL(SKU.CombineSku,'')='' THEN SKU.Sku ELSE SKU.CombineSku END AS Sku,
      ISNULL(Sku.Descr,'') SkuDescr,                  
      SUM(PickDetail.qty) as Qty,
      CASE PickDetail.UOM
           WHEN '1' THEN PACK.Pallet   
           WHEN '2' THEN PACK.CaseCnt    
           WHEN '3' THEN PACK.InnerPack  
           ELSE 1  END AS UOMQty,
      0 AS TempQty2,
      ISNULL((SELECT Distinct 'Y' FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @c_Loadkey AND  Zone = '3'), 'N') AS PrintedFlag, 
      '3' Zone,
      Pickdetail.Lot,                         
      ORDERS.DischargePlace CarrierKey,                                  
      '' AS VehicleNo,
      LotAttribute.Lottable02,                
      ISNULL(LotAttribute.Lottable04, '19000101') Lottable04,        
      PACK.Pallet,
      PACK.CaseCnt,
      pack.innerpack,
      PACK.Qty,
      ORDERS.ExternOrderKey AS ExternOrderKey,               
      ISNULL(LOC.LogicalLocation, '') AS LogicalLocation, 
      ISNULL(AreaDetail.AreaKey, '00') AS Areakey,
      ISNULL(OrderDetail.UOM, '') AS UOM,
      Pallet_cal = CASE Pack.Pallet WHEN 0 THEN 0 
                       ELSE FLOOR(SUM(PickDetail.qty) / Pack.Pallet)  
                    END,  
      Cartons_cal = 0,
      inner_cal = 0,
      Each_cal = 0,
      Total_cal = sum(pickdetail.qty),
      ISNULL(ORDERS.DeliveryDate, '19000101') DeliveryDate,        
      LotAttribute.Lottable01,                     
      ISNULL(LotAttribute.Lottable10,''),                     
      ISNULL(LotAttribute.Lottable05 , '19000101'), 
      ORDERS.DischargePlace,                        
      ORDERS.InvoiceNo,                
      ISNULL(ORDERS.C_Address4,'') AS Addr4,            
      ISNULL(ORDERS.C_City,'')  AS City,
      ORDERS.Storerkey,                                         
      CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END AS ShowBarcode,           
      CASE WHEN ISNULL(CLR1.Code,'') <> '' THEN 'Y' ELSE 'N' END AS Showcontactphone,    
      ISNULL(orders.c_contact1,'') as c_contact1,
      ISNULL(orders.c_phone1,'')  as c_phone1,
      CAST(STUFF((SELECT TOP 3 '/' + RTRIM(UPC) FROM UPC (NOLOCK) WHERE UPC.SKU = PickDetail.SKU AND UPC.StorerKey = ORDERS.Storerkey ORDER BY UPC.UPC FOR XML PATH('')),1,1,'' ) AS NVARCHAR(255)),
      CAST(ISNULL(S.Notes1,'') AS NVARCHAR(255)),
      ISNULL(LotAttribute.Lottable08,''),
      ORDERS.Ordergroup     --ML01
   FROM pickdetail WITH (NOLOCK)
   JOIN ORDERS WITH (NOLOCK) ON pickdetail.orderkey = orders.orderkey
   JOIN lotattribute WITH (NOLOCK) ON pickdetail.lot = lotattribute.lot
   JOIN loadplandetail WITH (NOLOCK) ON pickdetail.orderkey = loadplandetail.orderkey
   JOIN orderdetail WITH (NOLOCK) ON pickdetail.orderkey = orderdetail.orderkey 
                                 AND pickdetail.orderlinenumber = orderdetail.orderlinenumber         
   JOIN storer WITH (NOLOCK) ON pickdetail.storerkey = storer.storerkey
   JOIN #TEMP_SKU sku WITH (NOLOCK) ON pickdetail.sku = sku.sku and pickdetail.storerkey = sku.storerkey
   JOIN pack WITH (NOLOCK) ON pickdetail.packkey = pack.packkey
   JOIN loc WITH (NOLOCK) ON pickdetail.loc = loc.loc
   JOIN SKU S WITH (NOLOCK) ON S.StorerKey = ORDERS.StorerKey AND S.SKU = SKU.SKU
   LEFT outer JOIN routemaster WITH (NOLOCK) ON orders.route = routemaster.route
   LEFT outer JOIN areadetail WITH (NOLOCK) ON loc.putawayzone = areadetail.putawayzone
   LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (ORDERS.Storerkey = CLR.Storerkey AND CLR.Code = 'SHOWBARCODE'
                                         AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_print_pickorder121' AND ISNULL(CLR.Short,'') <> 'N')
   LEFT OUTER JOIN Codelkup CLR1 (NOLOCK) ON (ORDERS.Storerkey = CLR1.Storerkey AND CLR1.Code = 'SHOWCONTACTPHONE'
                                         AND CLR1.Listname = 'REPORTCFG' AND CLR1.Long = 'r_dw_print_pickorder121' AND ISNULL(CLR1.Short,'') <> 'N')
   WHERE PickDetail.Status < '5'  
     AND LoadPlanDetail.LoadKey = @c_LoadKey
   GROUP BY PickDetail.OrderKey,                            
            ISNULL(ORDERS.ConsigneeKey, ''),
            ISNULL(ORDERS.c_Company, ''),   
            ISNULL(ORDERS.C_Address1,''),
            ISNULL(ORDERS.C_Address2,''),
            ISNULL(ORDERS.C_Address3,''),
            ISNULL(ORDERS.C_Zip,''),
            ISNULL(ORDERS.Route,''),
            ISNULL(RouteMaster.Descr, ''),
            ORDERS.Door,
            CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes,  '')),                                    
            CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes2, '')),
            PickDetail.loc,   
            PickDetail.id,
            PickDetail.sku,                         
            CASE WHEN ISNULL(SKU.CombineSku,'')='' THEN SKU.Sku ELSE SKU.CombineSku END,
            ISNULL(Sku.Descr,''),                  
            CASE PickDetail.UOM
                 WHEN '1' THEN PACK.Pallet   
                 WHEN '2' THEN PACK.CaseCnt    
                 WHEN '3' THEN PACK.InnerPack  
                 ELSE 1  END,
            Pickdetail.Lot,                         
            LotAttribute.Lottable02,                
            ISNULL(LotAttribute.Lottable04, '19000101'),        
            PACK.Pallet,
            PACK.CaseCnt,
            pack.innerpack,
            PACK.Qty, 
            ORDERS.ExternOrderKey,
            ISNULL(LOC.LogicalLocation, ''),  
            ISNULL(AreaDetail.AreaKey, '00'), 
            ISNULL(OrderDetail.UOM, ''), 
            ISNULL(ORDERS.DeliveryDate, '19000101'),
            LotAttribute.Lottable01,
            ISNULL(LotAttribute.Lottable10,''),
            ISNULL(LotAttribute.Lottable05 , '19000101'),
            ORDERS.DischargePlace,                       
            ORDERS.InvoiceNo,                            
            ISNULL(ORDERS.C_Address4,''),
            ISNULL(ORDERS.C_City,''), 
            ORDERS.Storerkey,                                  
            CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END,    
            CASE WHEN ISNULL(CLR1.Code,'') <> '' THEN 'Y' ELSE 'N' END,  
            ISNULL(orders.c_contact1,''),                                 
            ISNULL(orders.c_phone1,''),
            ISNULL(S.Notes1,''),
            ISNULL(LotAttribute.Lottable08,''),
            ORDERS.Ordergroup     --ML01

   -- commented the cursor below and instead update directly the temp table
   -- update CASE qty
   UPDATE #TEMP_PICK
   SET Cartons_cal = CASE packcasecnt
                     WHEN 0 THEN 0
                     ELSE FLOOR(Total_cal/packcasecnt) - ((packpallet*Pallet_cal)/packcasecnt)
                     END
      
   -- update inner qty
   UPDATE #TEMP_PICK
   SET inner_cal = CASE packinner
                   WHEN 0 THEN 0
                   ELSE FLOOR(Total_cal/packinner) - ((packpallet*Pallet_cal)/packinner) - ((packcasecnt*Cartons_cal)/packinner)
                   END
      
   -- update each qty
   UPDATE #TEMP_PICK
   SET Each_cal = Total_cal - (packpallet*Pallet_cal) - (packcasecnt*Cartons_cal) - (packinner*inner_cal)

   UPDATE #TEMP_PICK
   SET    Pltcnt = TTLPLT.PltCnt
   FROM   ( SELECT OrderKey, PltCnt = COUNT(DISTINCT ISNULL(ID, 0))
            FROM  #TEMP_PICK
            WHERE ID > ''
            GROUP BY OrderKey ) AS TTLPLT
   WHERE #TEMP_PICK.OrderKey = TTLPLT.OrderKey

   BEGIN TRAN  
   -- Uses PickType as a Printed Flag  
   UPDATE PickHeader WITH (ROWLOCK) 
   SET PickType = '1', TrafficCop = NULL 
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

   SELECT @n_pickslips_required = Count(DISTINCT OrderKey) 
   FROM #TEMP_PICK
   WHERE PickSlipNo IS NULL
   IF @@ERROR <> 0
   BEGIN
      GOTO FAILURE
   END
   ELSE IF @n_pickslips_required > 0
   BEGIN
      EXECUTE nspg_GetKey 'PICKSLIP', 9, @c_pickheaderkey OUTPUT, @b_success OUTPUT, @n_err  OUTPUT, @c_errmsg OUTPUT, 0, @n_pickslips_required

      INSERT INTO PICKHEADER (PickHeaderKey,    OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)
      SELECT 'P' + RIGHT ( REPLICATE ('0', 9) + 
             dbo.fnc_LTrim( dbo.fnc_RTrim(
                STR( 
                   CAST(@c_pickheaderkey AS INT) + ( select count(distinct orderkey) 
                          from #TEMP_PICK as Rank 
                                                     WHERE Rank.OrderKey < #TEMP_PICK.OrderKey 
                                                     AND ISNULL(RTRIM(Rank.PickSlipNo),'') = '' ) -- SOS# 265314                                                     
                    ) -- str
                    )) -- rtrim
                 , 9) 
              , OrderKey, LoadKey, '0', '3', ''
      FROM #TEMP_PICK WHERE PickSlipNo IS NULL
      GROUP By LoadKey, OrderKey

      UPDATE #TEMP_PICK 
      SET PickSlipNo = PICKHEADER.PickHeaderKey
      FROM PICKHEADER WITH (NOLOCK)
      WHERE PICKHEADER.ExternOrderKey = #TEMP_PICK.LoadKey
      AND   PICKHEADER.OrderKey = #TEMP_PICK.OrderKey
      AND   PICKHEADER.Zone = '3'
      AND   #TEMP_PICK.PickSlipNo IS NULL
   END

   DECLARE @c_PickSlipNo        NVARCHAR(10)
      
   DECLARE CUR_ORDERS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT OrderKey, PickSlipNo
   FROM #TEMP_PICK (NOLOCK)
   ORDER BY OrderKey, PickSlipNo
   
   OPEN CUR_ORDERS
   FETCH NEXT FROM CUR_ORDERS INTO @c_OrderKey, @c_PickSlipNo
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      -- ScanInPickLog  
      IF @n_continue = 1 or @n_continue=2  
      BEGIN  
         EXEC dbo.isp_InsertPickDet_Log   
              @cOrderKey = @c_OrderKey,  
              @cOrderLineNumber='',  
              @n_err=@n_err OUTPUT,   
              @c_errmsg=@c_errmsg OUTPUT, 
              @cPickSlipNo = @c_PickSlipNo  
               
      END -- (continue =1) 
      FETCH NEXT FROM CUR_ORDERS INTO @c_OrderKey, @c_PickSlipNo
   END -- WHILE FETCH STATUS <> -1
   CLOSE CUR_ORDERS 
   DEALLOCATE CUR_ORDERS  
 
   GOTO SUCCESS
FAILURE:
   DELETE FROM #TEMP_PICK
SUCCESS:
   SELECT * FROM #TEMP_PICK  

   IF OBJECT_ID('tempdb..#TEMP_PICK') IS NOT NULL
      DROP TABLE #TEMP_PICK
    
END

GO