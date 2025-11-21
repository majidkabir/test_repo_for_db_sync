SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  nsp_GetPickSlipOrders58                            */
/* Creation Date: 2002-05-08                                            */
/* Copyright: IDS                                                       */
/* Written by: Administrator                                            */
/*                                                                      */
/* Purpose:  Pickslip for IDSMY                                         */
/*                                                                      */
/* Input Parameters:  @c_loadkey  - Loadkey                             */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_print_pickorder58                  */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.4                                                   */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author    Ver.  Purposes                                 */
/* 15-May-2015 CSCHONG   1.0   341661 - New field (CS01)                */
/* 03-07-2015  CSCHONG   1.1   Duliplicate from nsp_GetPickSlipOrders05 */
/* 2017-07-25  TLTING    1.2   review DynamicSQL                         */
/************************************************************************/

CREATE PROC [dbo].[nsp_GetPickSlipOrders58] (@c_loadkey NVARCHAR(10)) 
 AS
 BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
    DECLARE @c_pickheaderkey  NVARCHAR(10),
      @n_continue         int,
      @c_errmsg           NVARCHAR(255),
      @b_success          int,
      @n_err              int,
      @c_sku              NVARCHAR(20),
      @n_qty              int,
      @c_loc              NVARCHAR(10),
      @n_cases            int,
      @n_perpallet        int,
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
      @c_TrfRoom          NVARCHAR(5),  -- LoadPlan.TrfRoom
      @c_Notes1           NVARCHAR(60),
      @c_Notes2           NVARCHAR(60),
      @c_SkuDesc          NVARCHAR(60),
      @n_CaseCnt          int,
      @n_PalletCnt        int,
      @c_ReceiptTm        NVARCHAR(20),
      @c_PrintedFlag      NVARCHAR(1),
      @c_UOM              NVARCHAR(10),
      @n_UOM3             int,
      @c_Lot              NVARCHAR(10),
      @c_StorerKey        NVARCHAR(15),
      @c_Zone             NVARCHAR(1),
      @n_PgGroup          int,
      @n_TotCases         int,
      @n_RowNo            int,
      @c_PrevSKU          NVARCHAR(20),
      @n_SKUCount         int,
      @c_Carrierkey       NVARCHAR(60),
      @c_VehicleNo        NVARCHAR(10),
      @c_firstorderkey    NVARCHAR(10),
      @c_superorderflag   NVARCHAR(1),
      @c_firsttime        NVARCHAR(1),
      @c_logicalloc       NVARCHAR(18),
      @c_Lottable02       NVARCHAR(18),    -- ONG01
      @d_Lottable04       datetime,
      @n_packpallet       int,
      @n_packcasecnt      int,
      @c_externorderkey   NVARCHAR(30),  
      @n_pickslips_required int,  
      @c_areakey          NVARCHAR(10),
      @c_dischargeplace   NVARCHAR(30),    -- Nick  
      @c_invoiceno        NVARCHAR(20),    -- Nick
      @c_Addr4            NVARCHAR(45),    -- SOS121799
      @c_City             NVARCHAR(45)     -- SOS121799
                           
    DECLARE @c_PrevOrderKey NVARCHAR(10),
            @n_Pallets      int,
            @n_Cartons      int,
            @n_Eaches       int,
            @n_UOMQty       int

    SET @n_Continue = 1
    
    --NJOW01 Start
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
                        + ' JOIN LOADPLANDETAIL LD (NOLOCK) ON LD.Orderkey = O.Orderkey '
                        + ' WHERE LD.Loadkey = RTRIM(@c_Loadkey) '

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
       FROM   INFORMATION_SCHEMA.COLUMNS 
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
       FROM   INFORMATION_SCHEMA.COLUMNS 
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
       FROM   INFORMATION_SCHEMA.COLUMNS 
       WHERE  TABLE_NAME = @c_TableName
       AND    COLUMN_NAME = @c_ColName
       
       IF @c_ColType IN ('char', 'nvarchar', 'varchar') AND @c_TableName = 'SKU'
   	      SELECT @c_InsertSelect = @c_InsertSelect + ' + LTRIM(RTRIM(ISNULL('+ RTRIM(@c_udf03) + ',''''))) '       	                      	     
       ELSE
   	      SELECT @c_InsertSelect = @c_InsertSelect + ' + ''' + LTRIM(RTRIM(@c_udf03)) + ''' '   	                      	                   

       SET @cSQL = @c_InsertSelect + @c_FromWhere
   	
       EXEC sp_executesql @cSQL, N'@c_Loadkey nvarchar(10) ', @c_Loadkey    
                    
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
         TrfRoom          NVARCHAR(5) NULL,  -- LoadPlan.TrfRoom
         Notes1           NVARCHAR(60) NULL,
         Notes2           NVARCHAR(60) NULL,
         LOC              NVARCHAR(10) NULL, 
         ID               NVARCHAR(18) NULL,        -- Added by YokeBeen on 05-Aug-2002 (Ticket # 6692, 4657) 
         SKU              NVARCHAR(20),
         SkuDesc          NVARCHAR(60),
         Qty              int,
         TempQty1         int,
         TempQty2         int,
         PrintedFlag      NVARCHAR(1) NULL,
         Zone             NVARCHAR(1),
         PgGroup          int,
         RowNum           int,
         Lot              NVARCHAR(10),
         Carrierkey       NVARCHAR(60) NULL,
         VehicleNo        NVARCHAR(10) NULL,
         Lottable02       NVARCHAR(18) NULL,     -- ONG01
         Lottable04       datetime NULL,
         packpallet       int,
         packcasecnt      int, 
         packinner        int,               -- sos 7545 wally 27.aug.2002
         packeaches       int,               -- Added by YokeBeen on 05-Aug-2002 (Ticket # 6692, 4657) 
         externorderkey   NVARCHAR(30) NULL,
         LogicalLocation  NVARCHAR(18) NULL,  
         Areakey          NVARCHAR(10) NULL,     -- Added By YokeBeen on 05-Mar-2002 (Ticket # 3377)
         UOM              NVARCHAR(10),          -- Added By YokeBeen on 18-Mar-2002 (Ticket # 2539)
         Pallet_cal       int,  
         Cartons_cal      int,  
         inner_cal        int,               -- sos 7545 wally 27.aug.2002 
         Each_cal         int,  
         Total_cal        int,               -- Added by YokeBeen on 05-Aug-2002 (Ticket # 6692, 4657) 
         DeliveryDate     datetime NULL,
         Lottable01       NVARCHAR(18) NULL,     -- ONG01 
         Lottable03       NVARCHAR(18) NULL,     -- ONG01 
         Lottable05       datetime NULL,     -- ONG01 
         DischargePlace   NVARCHAR(30) NULL,     -- Nick
         InvoiceNo        NVARCHAR(20) NULL,     -- Nick
         palletcnt        int DEFAULT(0), -- SOS101659
         Addr4            NVARCHAR(45), -- SOS121799
         City             NVARCHAR(45)  -- SOS121799
       , Storerkey        NVARCHAR(15)  --(Wan01)
       , buyerpo          NVARCHAR(20) NULL --(CS01)
       , Short            NVARCHAR(20) NULL  --(CS01)
                         )
       INSERT INTO #TEMP_PICK
            (PickSlipNo,          LoadKey,         OrderKey,         ConsigneeKey,
             Company,             Addr1,           Addr2,            PgGroup,
             Addr3,               PostCode,        Route,
             Route_Desc,          TrfRoom,         Notes1,           RowNum,
            Notes2,              LOC,             ID,             SKU,
             SkuDesc,             Qty,             TempQty1,
             TempQty2,            PrintedFlag,     Zone,
             Lot,                 CarrierKey,      VehicleNo,        Lottable02,
             Lottable04,          packpallet,      packcasecnt,   packinner,     
             packeaches,   externorderkey,       LogicalLocation,      Areakey,          UOM,  
             Pallet_cal,          Cartons_cal,     inner_cal,     Each_cal,         Total_cal,  
             DeliveryDate  ,Lottable01 ,Lottable03 ,Lottable05 ,     -- ONG01
             DischargePlace ,InvoiceNo , Addr4, City 
            ,Storerkey,buyerpo,short )                              --(Wan01)   --(CS01)
        SELECT
        (SELECT PICKHEADERKEY FROM PICKHEADER WITH (NOLOCK)
            WHERE ExternOrderKey = @c_LoadKey 
            AND OrderKey = PickDetail.OrderKey 
            AND ZONE = '3'),
        @c_LoadKey as LoadKey,                 
        PickDetail.OrderKey,                            
        -- Changed by YokeBeen on 08-Aug-2002 (Ticket # 6692) - from BillToKey to ConsigneeKey.  
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
        PickDetail.id,        -- Added by YokeBeen on 05-Aug-2002 (Ticket # 6692, 4657) 
        --PickDetail.sku,                         
   		  CASE WHEN ISNULL(SKU.CombineSku,'')='' THEN SKU.Sku ELSE SKU.CombineSku END AS Sku,  --NJOW01
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
        ISNULL(ORDERS.DischargePlace,'') CarrierKey,                                  
        '' AS VehicleNo,
        LotAttribute.Lottable02,                
        IsNUll(LotAttribute.Lottable04, '19000101') Lottable04,        
        PACK.Pallet,
        PACK.CaseCnt,
        pack.innerpack, -- sos 7545 wally 27.aug.2002
        PACK.Qty,             -- Added by YokeBeen on 05-Aug-2002 (Ticket # 6692, 4657) 
        ORDERS.ExternOrderKey AS ExternOrderKey,               
        ISNULL(LOC.LogicalLocation, '') AS LogicalLocation, 
       IsNull(AreaDetail.AreaKey, '00') AS Areakey,     -- Added By YokeBeen on 05-Mar-2002 (Ticket # 3377)
       IsNull(OrderDetail.UOM, '') AS UOM,            -- Added By YokeBeen on 18-Mar-2002 (Ticket # 2539)
       /* Added By YokeBeen on 20-Mar-2002 (Ticket # 2539 / 3377) - Start */
       Pallet_cal = case Pack.Pallet when 0 then 0 
                        else FLOOR(SUM(PickDetail.qty) / Pack.Pallet)  
                     end,  
       Cartons_cal = 0,
       inner_cal = 0,
       Each_cal = 0,
       Total_cal = sum(pickdetail.qty),
        IsNUll(ORDERS.DeliveryDate, '19000101') DeliveryDate        
       /* Added By YokeBeen on 20-Mar-2002 (Ticket # 2539 / 3377) - End */
       ,LotAttribute.Lottable01                       -- ONG01
       ,LotAttribute.Lottable03                       -- ONG01
       ,ISNULL(LotAttribute.Lottable05 , '19000101')  -- ONG01
       ,ISNULL(ORDERS.DischargePlace,'')                         -- Nick
       ,ORDERS.InvoiceNo                              -- Nick
       ,IsNull(ORDERS.C_Address4,'') AS Addr4            
       ,IsNull(ORDERS.C_City,'')  AS City
       ,IsNull(ORDERS.Storerkey,'')  AS Storerkey     --(Wan01)
       ,ISNULL(ORDERS.BuyerPO,'') AS BuyerPO         --(CS01)
       ,ISNULL(CLR.short,'N') AS short       --(CS01)
      FROM pickdetail WITH (NOLOCK)  
      JOIN ORDERS WITH (NOLOCK) ON pickdetail.orderkey = orders.orderkey
      JOIN lotattribute WITH (NOLOCK) ON pickdetail.lot = lotattribute.lot
      JOIN loadplandetail WITH (NOLOCK) ON pickdetail.orderkey = loadplandetail.orderkey
      JOIN orderdetail WITH (NOLOCK) ON pickdetail.orderkey = orderdetail.orderkey 
                                    AND pickdetail.orderlinenumber = orderdetail.orderlinenumber         
      JOIN storer WITH (NOLOCK) ON pickdetail.storerkey = storer.storerkey
      --JOIN sku WITH (NOLOCK) ON pickdetail.sku = sku.sku and pickdetail.storerkey = sku.storerkey
      JOIN #TEMP_SKU sku WITH (NOLOCK) ON pickdetail.sku = sku.sku and pickdetail.storerkey = sku.storerkey  --NJOW01
      JOIN pack WITH (NOLOCK) ON pickdetail.packkey = pack.packkey
      JOIN loc WITH (NOLOCK) ON pickdetail.loc = loc.loc
      left outer JOIN routemaster WITH (NOLOCK) ON orders.route = routemaster.route
      left outer JOIN areadetail WITH (NOLOCK) ON loc.putawayzone = areadetail.putawayzone
      LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (Orders.Storerkey = CLR.Storerkey AND CLR.Code = 'SHOWFIELD'   
                                       AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_print_pickorder05' AND ISNULL(CLR.Short,'') <> 'N')  
     WHERE PickDetail.Status < '5'  
       AND LoadPlanDetail.LoadKey = @c_LoadKey
     GROUP BY PickDetail.OrderKey,                            
        -- Changed by YokeBeen on 08-Aug-2002 (Ticket # 6692) - from BillToKey to ConsigneeKey.  
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
        PickDetail.id,        -- Added by YokeBeen on 05-Aug-2002 (Ticket # 6692, 4657) 
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
        pack.innerpack,    -- sos 7545 wally 27.aug.2002
        PACK.Qty,             -- Added by YokeBeen on 05-Aug-2002 (Ticket # 6692, 4657) 
        ORDERS.ExternOrderKey,
        ISNULL(LOC.LogicalLocation, ''),  
       IsNull(AreaDetail.AreaKey, '00'),     -- Added By YokeBeen on 05-Mar-2002 (Ticket # 3377)
       IsNull(OrderDetail.UOM, ''),          -- Added By YokeBeen on 18-Mar-2002 (Ticket # 2539)
       IsNUll(ORDERS.DeliveryDate, '19000101')
       ,LotAttribute.Lottable01     -- ONG01
       ,LotAttribute.Lottable03     -- ONG01
       ,IsNUll(LotAttribute.Lottable05 , '19000101')     -- ONG01
       ,ORDERS.DischargePlace                            -- Nick
       ,ORDERS.InvoiceNo                                 -- Nick
       ,IsNull(ORDERS.C_Address4,'')
       ,IsNull(ORDERS.C_City,'') 
       ,IsNull(ORDERS.Storerkey,'')                                                                --(Wan01)
       ,ISNULL(ORDERS.BuyerPO,'')        --(CS01)
       ,CLR.short --(CS01)
      -- SOS 7236
      -- wally 16.aug.2002
      -- commented the cursor below and instead update directly the temp table
      -- update case qty
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

      -- Start : SOS101659
      UPDATE #temp_pick
      SET    palletcnt = TTLPLT.PltCnt
      FROM   ( SELECT Orderkey, PltCnt = COUNT(DISTINCT ISNULL(ID, 0))
               FROM  #temp_Pick
               WHERE ID > ''
               GROUP BY Orderkey ) As TTLPLT
      WHERE #temp_pick.Orderkey = TTLPLT.Orderkey
      -- End   : SOS101659

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

      -- tlting01
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
     SELECT * FROM #TEMP_PICK  
     DROP Table #TEMP_PICK  
 END

GO