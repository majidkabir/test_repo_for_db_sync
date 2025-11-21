SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_GetPickSlipOrders94_KFMY                       */
/* Creation Date: 2020-11-02                                            */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose:  WMS-15590 - Pickslip for KFMY                              */
/*           Copied from isp_GetPickSlipOrders94                        */
/*                                                                      */
/* Input Parameters:  @c_loadkey  - Loadkey                             */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_print_pickorder94_KFMY             */
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
/* 05-OCT-2021 CSCHONG   1.0   Devops scripts combine                   */
/* 05-OCT-2021 CSCHONG   1.1   WMS-18074 - add new field (CS01)         */
/* 06-MAY-2022 IANKOONG  1.2   INC1825510 - increase nvarchar           */
/* 13-OCT-2022 MINGLE    1.3   WMS-20945 - add buyerpo (ML01)           */
/************************************************************************/
CREATE PROC [dbo].[isp_GetPickSlipOrders94_KFMY] (@c_loadkey NVARCHAR(10))    
 AS    
 BEGIN    
   SET NOCOUNT ON     
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    
       
    DECLARE @c_pickheaderkey  NVARCHAR(10),    
      @n_continue         INT,    
      @c_errmsg           NVARCHAR(255),    
      @b_success          INT,    
      @n_err              INT,    
      @c_sku              NVARCHAR(20),    
      @n_qty              INT,    
      @c_loc              NVARCHAR(10),    
      @n_cases            INT,    
      @n_perpallet        INT,    
      @c_storer           NVARCHAR(15),    
      @c_orderkey         NVARCHAR(10),    
      @c_ConsigneeKey     NVARCHAR(15),    
      @c_Company          NVARCHAR(45),    
      @c_Addr1            NVARCHAR(45),    
      @c_Addr2            NVARCHAR(45),    
      @c_Addr3            NVARCHAR(45),    
      @c_PostCode         NVARCHAR(15),    
      @c_Route            NVARCHAR(10),    
      @c_Route_Desc       NVARCHAR(60), -- RouteMaster.Desc    
      @c_TrfRoom          NVARCHAR(10),  -- LoadPlan.TrfRoom  IANKOONG  1.2  
      @c_Notes1           NVARCHAR(60),    
      @c_Notes2           NVARCHAR(60),    
      @c_SkuDesc          NVARCHAR(60),    
      @n_CaseCnt          INT,    
      @n_PalletCnt        INT,    
      @c_ReceiptTm        NVARCHAR(20),    
      @c_PrintedFlag      NVARCHAR(1),    
      @c_UOM              NVARCHAR(10),    
      @n_UOM3             INT,    
      @c_Lot              NVARCHAR(10),    
      @c_StorerKey        NVARCHAR(15),    
      @c_Zone             NVARCHAR(1),    
      @n_PgGroup          INT,    
      @n_TotCases         INT,    
      @n_RowNo            INT,    
      @c_PrevSKU          NVARCHAR(20),    
      @n_SKUCount         INT,    
      @c_Carrierkey       NVARCHAR(60),    
      @c_VehicleNo        NVARCHAR(10),    
      @c_firstorderkey    NVARCHAR(10),    
      @c_superorderflag   NVARCHAR(1),    
      @c_firsttime        NVARCHAR(1),    
      @c_logicalloc       NVARCHAR(18),    
      @c_Lottable02       NVARCHAR(18),      
      @d_Lottable04       DATETIME,    
      @n_packpallet       INT,    
      @n_packcasecnt      INT,    
      @c_externorderkey   NVARCHAR(50),      
      @n_pickslips_required INT,      
      @c_areakey          NVARCHAR(10),    
      @c_dischargeplace   NVARCHAR(30),      
      @c_invoiceno        NVARCHAR(20),      
      @c_Addr4            NVARCHAR(45),      
      @c_City             NVARCHAR(45),
		@c_BuyerPO			  NVARCHAR(20)
                               
    DECLARE @c_PrevOrderKey NVARCHAR(10),    
            @n_Pallets      INT,    
            @n_Cartons      INT,    
            @n_Eaches       INT,    
            @n_UOMQty       INT,    
            @c_ISsortsku    NVARCHAR(1),    
            @c_facility     NVARCHAR(10) = ''     
    
    SET @n_Continue = 1    
        
    --NJOW01 Start    
    DECLARE @c_udf01 NVARCHAR(60),    
            @c_udf02 NVARCHAR(60),    
            @c_udf03 NVARCHAR(60),    
            @c_TableName NVARCHAR(100),    
            @c_ColName NVARCHAR(100),    
            @c_ColType NVARCHAR(100),    
            @c_ISCombineSKU NCHAR(1),    
            @cSQL NVARCHAR(MAX),    
            @c_FromWhere NVARCHAR(2000),                  
            @c_InsertSelect NVARCHAR(2000)                            
                
    SET @c_ISCombineSKU = 'N'    
    SET @c_ISsortsku = 'N'    
                  
    CREATE TABLE #TEMP_SKU (Storerkey NVARCHAR(15) NULL, SKU NVARCHAR(20) NULL, DESCR NVARCHAR(60) NULL, COMBINESKU NVARCHAR(100) NULL)    
        
    SELECT TOP 1 @c_Storer = Storerkey,@c_facility = Facility               --CS01    
    FROM ORDERS (NOLOCK)    
    WHERE Loadkey = @c_Loadkey    
           
    SELECT @c_udf01 = ISNULL(CL.UDF01,''),    
           @c_udf02 = ISNULL(CL.UDF02,''),    
           @c_udf03 = ISNULL(CL.UDF03,'')    
    FROM CODELKUP CL (NOLOCK)    
    WHERE Listname = 'COMBINESKU'    
    AND Code = 'CONCATENATESKU'    
    AND Storerkey = @c_Storer    
    
   SELECT @c_ISsortsku = short     
   FROM dbo.CODELKUP WITH (NOLOCK)     
   WHERE LISTNAME='PLISTSORT' AND storerkey = @c_storer AND long ='r_dw_print_pickorder94_kfmy'     
   AND code = 'SORTSKU'    
       
        
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
          SET @c_ColName   = SUBSTRING(@c_udf01, CHARINDEX('.', @c_udf01) + 1, LEN(@c_udf01) - CHARINDEX('.', @c_udf01))    
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
          SET @c_ColName   = SUBSTRING(@c_udf02, CHARINDEX('.', @c_udf02) + 1, LEN(@c_udf02) - CHARINDEX('.', @c_udf02))    
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
          SET @c_ColName   = SUBSTRING(@c_udf03, CHARINDEX('.', @c_udf03) + 1, LEN(@c_udf03) - CHARINDEX('.', @c_udf03))    
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
    --NJOW01 End    
    
    CREATE TABLE #TEMP_PICK    
       ( PickSlipNo        NVARCHAR(10) NULL,    
         LoadKey           NVARCHAR(10),    
         OrderKey          NVARCHAR(10),    
         ConsigneeKey      NVARCHAR(15),    
         Company           NVARCHAR(45),    
         Addr1             NVARCHAR(45) NULL,    
         Addr2             NVARCHAR(45) NULL,    
         Addr3             NVARCHAR(45) NULL,    
         PostCode          NVARCHAR(15) NULL,    
         Route             NVARCHAR(10) NULL,    
         Route_Desc        NVARCHAR(60) NULL, -- RouteMaster.Desc    
         TrfRoom           NVARCHAR(10) NULL,  -- LoadPlan.TrfRoom  IANKOONG  1.2  
         Notes1            NVARCHAR(60) NULL,    
         Notes2            NVARCHAR(60) NULL,    
         LOC               NVARCHAR(10) NULL,     
         ID                NVARCHAR(18) NULL,       
         SKU               NVARCHAR(20),    
         SkuDesc           NVARCHAR(60),    
         Qty               int,    
         TempQty1          int,    
         TempQty2          int,    
         PrintedFlag       NVARCHAR(1) NULL,    
         Zone              NVARCHAR(1), 
   PgGroup           int,    
         RowNum            int,    
         Lot               NVARCHAR(10),    
         Carrierkey        NVARCHAR(60) NULL,    
         VehicleNo         NVARCHAR(10) NULL,    
         Lottable02        NVARCHAR(18) NULL,       
         Lottable04        datetime NULL,    
         packpallet        int,    
         packcasecnt       int,     
         packinner         int,                     
         packeaches        int,                     
         externorderkey    NVARCHAR(50) NULL,       
         LogicalLoc        NVARCHAR(18) NULL,      
         Areakey           NVARCHAR(10) NULL,       
         UOM               NVARCHAR(10),            
         Pallet_cal        int,      
         Cartons_cal       int,      
         inner_cal         int,                  
         Each_cal          int,      
         Total_cal         int,                  
         DeliveryDate      datetime NULL,    
         Lottable01        NVARCHAR(18) NULL,     
         Lottable03        NVARCHAR(18) NULL,     
         Lottable05        datetime NULL,         
         DischargePlace    NVARCHAR(30) NULL,     
         InvoiceNo         NVARCHAR(20) NULL,     
         Pltcnt            int NULL,          
         Addr4             NVARCHAR(45),     
         City              NVARCHAR(45),      
         Storerkey         NVARCHAR(15),      
         showbarcode       NVARCHAR(1),       
         showcontactphone  NVARCHAR(1),       
         c_contact1        NVARCHAR(45),      
         c_phone1          NVARCHAR(45),      
         LocationType      NVARCHAR(10),   --WL01    
         VAS               NVARCHAR(60),   --WL02    
         ShowVAS           NVARCHAR(10),   --WL02    
         PackDescr         NVARCHAR(90),   --CS01 
			BuyerPO		      NVARCHAR(20)	 --ML01
        )    
    
       INSERT INTO #TEMP_PICK    
            (PickSlipNo,          LoadKey,         OrderKey,         ConsigneeKey,    
             Company,             Addr1,           Addr2,            PgGroup,    
             Addr3,               PostCode,        Route,    
             Route_Desc,          TrfRoom,         Notes1,           RowNum,    
             Notes2,              LOC,             ID,               SKU,    
             SkuDesc,             Qty,             TempQty1,    
             TempQty2,            PrintedFlag,     Zone,    
             Lot,                 CarrierKey,      VehicleNo,        Lottable02,    
             Lottable04,          packpallet,      packcasecnt,      packinner,         
             packeaches,          externorderkey,  LogicalLoc,       Areakey,      UOM,      
             Pallet_cal,          Cartons_cal,     inner_cal,        Each_cal,     Total_cal,      
             DeliveryDate,        Lottable01,      Lottable03 ,      Lottable05 ,        
             DischargePlace,      InvoiceNo,       Addr4,            City,     
             Storerkey,           showbarcode,     showcontactphone, c_contact1,   c_phone1,       
             LocationType,        VAS,             ShowVAS,			   PackDescr,	  BuyerPO)  --WL01   --WL02  --CS01	--ML01    
        SELECT    
        (SELECT PICKHEADERKEY FROM PICKHEADER WITH (NOLOCK)    
            WHERE ExternOrderKey = @c_LoadKey     
            AND OrderKey = PickDetail.OrderKey     
            AND ZONE = '3'),    
        @c_LoadKey as LoadKey,                     
        PickDetail.OrderKey,                                
        IsNull(ORDERS.ConsigneeKey, '') AS ConsigneeKey,      
        IsNull(ORDERS.c_Company, '')  AS Company,       
        IsNull(ORDERS.C_Address1,'') AS Addr1,                
        IsNull(ORDERS.C_Address2,'')  AS Addr2,    
        0 AS PgGroup,                                  
        IsNull(ORDERS.C_Address3,'') AS Addr3,                
        IsNull(ORDERS.C_Zip,'') AS PostCode,    
        IsNull(ORDERS.Route,'') AS Route,             
        IsNull(RouteMaster.Descr, '') Route_Desc,           
        ORDERS.Door AS TrfRoom,    
        CONVERT(NVARCHAR(60), IsNull(ORDERS.Notes,  '')) Notes1,                                
        0 AS RowNo,     
        CONVERT(NVARCHAR(60), IsNull(ORDERS.Notes2, '')) Notes2,    
        PickDetail.loc,       
        lli.id,--PickDetail.id,                                       --CS01    
        --PickDetail.sku,                             
        CASE WHEN ISNULL(SKU.CombineSku,'')='' THEN SKU.Sku ELSE SKU.CombineSku END AS Sku,     
        IsNULL(Sku.Descr,'') SkuDescr,                      
        SUM(PickDetail.qty) as Qty,    
        CASE PickDetail.UOM    
             WHEN '1' THEN PACK.Pallet       
             WHEN '2' THEN PACK.CaseCnt        
             WHEN '3' THEN PACK.InnerPack      
             ELSE 1  END AS UOMQty,    
        0 AS TempQty2,    
        IsNull((SELECT Distinct 'Y' FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @c_Loadkey AND  Zone = '3'), 'N') AS PrintedFlag,     
        '3' Zone,    
        Pickdetail.Lot,                             
        ORDERS.DischargePlace CarrierKey,                                      
        '' AS VehicleNo,    
        LotAttribute.Lottable02,                    
        IsNUll(LotAttribute.Lottable04, '19000101') Lottable04,            
        PACK.Pallet,    
        PACK.CaseCnt,    
        pack.innerpack,     
        PACK.Qty,                 
        ORDERS.ExternOrderKey AS ExternOrderKey,                   
        ISNULL(LOC.LogicalLocation, '') AS LogicalLocation,     
        IsNull(AreaDetail.AreaKey, '00') AS Areakey,        
        IsNull(OrderDetail.UOM, '') AS UOM,             
        Pallet_cal = case Pack.Pallet when 0 then 0     
                        else FLOOR(SUM(PickDetail.qty) / Pack.Pallet)      
                     end,      
        Cartons_cal = 0,    
        inner_cal = 0,    
        Each_cal = 0,    
        Total_cal = sum(pickdetail.qty),    
        IsNUll(ORDERS.DeliveryDate, '19000101') DeliveryDate            
       ,LotAttribute.Lottable01                           
       ,LotAttribute.Lottable03                           
       ,ISNULL(LotAttribute.Lottable05 , '19000101')      
       ,ORDERS.DischargePlace                             
       ,ORDERS.InvoiceNo                                  
       ,IsNull(ORDERS.C_Address4,'') AS Addr4                
       ,IsNull(ORDERS.C_City,'')  AS City    
       ,IsNull(ORDERS.Storerkey,'')  AS Storerkey                                              
       ,CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END AS ShowBarcode               
       ,CASE WHEN ISNULL(CLR1.Code,'') <> '' THEN 'Y' ELSE 'N' END AS Showcontactphone         
       ,isnull(orders.c_contact1,'') as c_contact1    
       ,isnull(orders.c_phone1,'')  as c_phone1    
       ,LOC.LocationType              --WL01    
       ,ISNULL(CS.UDF01,'') AS VAS    --WL02    
       ,CASE WHEN ISNULL(CLR2.Code,'') <> '' THEN 'Y' ELSE 'N' END AS ShowVAS    --WL02    
       ,PACK.PackDescr                                                           --CS01 
		 ,ORDERS.BuyerPO	--ML01
      FROM pickdetail WITH (NOLOCK)    
      JOIN ORDERS WITH (NOLOCK) ON pickdetail.orderkey = orders.orderkey    
      JOIN lotattribute WITH (NOLOCK) ON pickdetail.lot = lotattribute.lot    
      JOIN loadplandetail WITH (NOLOCK) ON pickdetail.orderkey = loadplandetail.orderkey    
      JOIN orderdetail WITH (NOLOCK) ON pickdetail.orderkey = orderdetail.orderkey     
                                    AND pickdetail.orderlinenumber = orderdetail.orderlinenumber             
      JOIN storer WITH (NOLOCK) ON pickdetail.storerkey = storer.storerkey    
      --JOIN sku WITH (NOLOCK) ON pickdetail.sku = sku.sku and pickdetail.storerkey = sku.storerkey    
      JOIN #TEMP_SKU sku WITH (NOLOCK) ON pickdetail.sku = sku.sku and pickdetail.storerkey = sku.storerkey    
      JOIN pack WITH (NOLOCK) ON pickdetail.packkey = pack.packkey    
      JOIN loc WITH (NOLOCK) ON pickdetail.loc = loc.loc    
      LEFT OUTER JOIN ConsigneeSKU CS WITH (NOLOCK) ON CS.ConsigneeKey = ORDERS.ConsigneeKey  --WL02    
    AND CS.StorerKey = ORDERS.StorerKey        --WL02    
                                                   AND CS.SKU = PICKDETAIL.Sku                --WL02    
      left outer JOIN routemaster WITH (NOLOCK) ON orders.route = routemaster.route    
      left outer JOIN areadetail WITH (NOLOCK) ON loc.putawayzone = areadetail.putawayzone    
      LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (ORDERS.Storerkey = CLR.Storerkey AND CLR.Code = 'SHOWBARCODE'    
                                       AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_print_pickorder94_kfmy' AND ISNULL(CLR.Short,'') <> 'N')    
      LEFT OUTER JOIN Codelkup CLR1 (NOLOCK) ON (ORDERS.Storerkey = CLR1.Storerkey AND CLR1.Code = 'SHOWCONTACTPHONE'    
                                       AND CLR1.Listname = 'REPORTCFG' AND CLR1.Long = 'r_dw_print_pickorder94_kfmy' AND ISNULL(CLR1.Short,'') <> 'N')    
      LEFT OUTER JOIN Codelkup CLR2 (NOLOCK) ON (ORDERS.Storerkey = CLR2.Storerkey AND CLR2.Code = 'ShowVAS'    
                                       AND CLR2.Listname = 'REPORTCFG' AND CLR2.Long = 'r_dw_print_pickorder94_kfmy' AND ISNULL(CLR2.Short,'') <> 'N')    
     --CS01 START    
     JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON LLi.lot = Pickdetail.lot AND lli.sku=pickdetail.sku     
                                          AND lli.StorerKey=pickdetail.storerkey AND lli.loc = pickdetail.loc AND lli.Id=pickdetail.id    
     --C01 END    
     WHERE PickDetail.Status < '5'      
       AND LoadPlanDetail.LoadKey = @c_LoadKey    
     GROUP BY PickDetail.OrderKey,                                
        IsNull(ORDERS.ConsigneeKey, ''),    
        IsNull(ORDERS.c_Company, ''),       
        IsNull(ORDERS.C_Address1,''),    
        IsNull(ORDERS.C_Address2,''),    
        IsNull(ORDERS.C_Address3,''),    
        IsNull(ORDERS.C_Zip,''),    
        IsNull(ORDERS.Route,''),    
        IsNull(RouteMaster.Descr, ''),    
        ORDERS.Door,    
        CONVERT(NVARCHAR(60), IsNull(ORDERS.Notes,  '')),                                        
        CONVERT(NVARCHAR(60), IsNull(ORDERS.Notes2, '')),    
        PickDetail.loc,       
        lli.id, --PickDetail.id,                            --CS01    
        PickDetail.sku,                             
        CASE WHEN ISNULL(SKU.CombineSku,'')='' THEN SKU.Sku ELSE SKU.CombineSku END, --NJOW01    
        IsNULL(Sku.Descr,''),                      
        CASE PickDetail.UOM    
             WHEN '1' THEN PACK.Pallet       
             WHEN '2' THEN PACK.CaseCnt        
             WHEN '3' THEN PACK.InnerPack      
             ELSE 1  END,    
        Pickdetail.Lot,                             
        LotAttribute.Lottable02,                    
        IsNUll(LotAttribute.Lottable04, '19000101'),            
        PACK.Pallet,    
        PACK.CaseCnt,    
        pack.innerpack,        
        PACK.Qty,                
        ORDERS.ExternOrderKey,    
        ISNULL(LOC.LogicalLocation, ''),      
        IsNull(AreaDetail.AreaKey, '00'),        
        IsNull(OrderDetail.UOM, ''),             
        IsNUll(ORDERS.DeliveryDate, '19000101')    
       ,LotAttribute.Lottable01        
       ,LotAttribute.Lottable03        
       ,IsNUll(LotAttribute.Lottable05 , '19000101')        
       ,ORDERS.DischargePlace                               
       ,ORDERS.InvoiceNo                                    
       ,IsNull(ORDERS.C_Address4,'')    
       ,IsNull(ORDERS.C_City,'')     
       ,IsNull(ORDERS.Storerkey,'')                                                   
       ,CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END                     
       , CASE WHEN ISNULL(CLR1.Code,'') <> '' THEN 'Y' ELSE 'N' END                   
       ,isnull(orders.c_contact1,'')                                                  
       ,isnull(orders.c_phone1,'')                                                    
       ,LOC.LocationType              --WL01    
       ,ISNULL(CS.UDF01,'')           --WL02    
       ,CASE WHEN ISNULL(CLR2.Code,'') <> '' THEN 'Y' ELSE 'N' END   --WL02    
       ,PACK.PackDescr                                               --CS01 
		 ,ORDERS.BuyerPO	--ML01
    
      UPDATE #temp_pick    
      SET cartons_cal = case packcasecnt    
                           when 0 then 0    
                           else floor(total_cal/packcasecnt) - ((packpallet*pallet_cal)/packcasecnt)    
                        end    
          
      -- update inner qty    
      update #temp_pick    
      set inner_cal = case packinner    
                        when 0 then 0    
                        else floor(total_cal/packinner) -     
                              ((packpallet*pallet_cal)/packinner) - ((packcasecnt*cartons_cal)/packinner)    
                      end    
          
      -- update each qty    
      update #temp_pick    
      set each_cal = total_cal - (packpallet*pallet_cal) - (packcasecnt*cartons_cal) - (packinner*inner_cal)    
    
      UPDATE #temp_pick    
      SET    Pltcnt = TTLPLT.PltCnt    
      FROM   ( SELECT Orderkey, PltCnt = COUNT(DISTINCT ISNULL(ID, 0))    
FROM  #temp_Pick    
               WHERE ID > ''    
               GROUP BY Orderkey ) As TTLPLT    
      WHERE #temp_pick.Orderkey = TTLPLT.Orderkey    
    
    
     BEGIN TRAN      
     -- Uses PickType as a Printed Flag      
     UPDATE PickHeader WITH (ROWLOCK) SET PickType = '1', TrafficCop = NULL     
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
     ELSE BEGIN      
         IF @@TRANCOUNT > 0       
         BEGIN      
             COMMIT TRAN      
         END      
         ELSE BEGIN      
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
 --             SELECT 'P' + RIGHT ( REPLICATE ('0', 9) +     
 --             dbo.fnc_LTrim( dbo.fnc_RTrim(    
 --                STR(     
 --                   CAST(@c_pickheaderkey AS int) + ( select count(distinct orderkey)     
 --                                                     from #TEMP_PICK as Rank     
 --                                                     WHERE Rank.OrderKey < #TEMP_PICK.OrderKey )     
 --                    ) -- str    
 --                    )) -- rtrim    
 --                 , 9)     
 --              , OrderKey, LoadKey, '0', '8', ''    
 --             FROM #TEMP_PICK WHERE PickSlipNo IS NULL    
 --             GROUP By LoadKey, OrderKey    
         INSERT INTO PICKHEADER (PickHeaderKey,    OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)    
             SELECT 'P' + RIGHT ( REPLICATE ('0', 9) +     
             dbo.fnc_LTrim( dbo.fnc_RTrim(    
                STR(     
                   CAST(@c_pickheaderkey AS int) + ( select count(distinct orderkey)     
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
    
      Declare @c_PickSlipNo        NVARCHAR(10)    
          
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
     SELECT * FROM #TEMP_PICK   --CS01 START    
     ORDER BY  loadkey,    
               orderkey,    
               areakey,    
               LogicalLoc,    
               CASE WHEN @c_ISsortsku = 'N' THEN loc ELSE sku END,    
               CASE WHEN @c_ISsortsku = 'N' THEN sku ELSE loc END,    
               Lottable02,    
               locationtype    
    
     DROP Table #TEMP_PICK      
 END 





GO