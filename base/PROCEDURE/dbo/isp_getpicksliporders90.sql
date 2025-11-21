SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Store Procedure: isp_GetPickSlipOrders90                              */
/* Creation Date: 19-APR-2019                                            */
/* Copyright: IDS                                                        */
/* Written by: CSCHONG                                                   */
/*                                                                       */
/* Purpose: WMS-8737 CN_pandora pick list CR                             */
/*          Modified from isp_GetPickSlipOrders53                        */            
/*                                                                       */
/* Called By: r_dw_print_pickorder90                                     */
/*                                                                       */
/* PVCS Version: 1.1                                                     */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author  Ver.  Purposes                                   */
/*16/05/2019    WLCHOOI 1.0   Same loc, same sku, different lot - do not */
/*                            show sku serial num (WL01)                 */
/*************************************************************************/

CREATE PROC [dbo].[isp_GetPickSlipOrders90] (@c_loadkey NVARCHAR(10)) 
 AS
 BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
    DECLARE @c_pickheaderkey  NVARCHAR(10),
      @n_continue             int,
      @c_errmsg               NVARCHAR(255),
      @b_success              int,
      @n_err                  int,
      @n_pickslips_required   INT,
      @n_SortBySkuLoc         INT   --CS01     

DECLARE @c_Pickslipno        NVARCHAR(20),  
        @c_Getloadkey        NVARCHAR(20),  
        @c_Orderkey          NVARCHAR(20), 
        @c_externorderkey    NVARCHAR(20),  
        @c_sku               NVARCHAR(20), 
        @n_line              int

    CREATE TABLE #TEMP_SKU(
    ORDERKEY         NVARCHAR(10),
    LOC              NVARCHAR(10) NULL,
    SKU              NVARCHAR(20),
    SkuDesc          NVARCHAR(60),
    Areakey          NVARCHAR(10) NULL,
    LogicalLoc       NVARCHAR(18) NULL,
    Lottable02       NVARCHAR(18) NULL,
    Lottable03       NVARCHAR(18) NULL,
    Lottable04       datetime NULL,
    Qty              INT,
    Carton           INT,
    Each             INT )

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
         Qty              int,
         TempQty1         int NULL,
         TempQty2         int,
         PrintedFlag      NVARCHAR(1) NULL,
         Zone             NVARCHAR(1),
         PgGroup          int,
         RowNum           int,
         Lot              NVARCHAR(10),
         Carrierkey       NVARCHAR(60) NULL,
         VehicleNo        NVARCHAR(10) NULL,
         Lottable02       NVARCHAR(10) NULL,
         Lottable04       datetime NULL,
         Lottable05       datetime NULL,
         packpallet       int,
         packcasecnt      int,
         externorderkey   NVARCHAR(50) NULL,   --tlting_ext
         LogicalLoc       NVARCHAR(18) NULL,  
         Areakey          NVARCHAR(10) NULL,     -- Added By YokeBeen on 05-Mar-2002 (Ticket # 3377)
         UOM              NVARCHAR(10) NULL,    -- Added By YokeBeen on 18-Mar-2002 (Ticket # 2539)
         DeliveryDate     NVARCHAR(10) NULL,    -- Added by MaryVong on 29-Dec-2003 (FBR#18681)
         Lottable03       NVARCHAR(18) NULL,      -- Added By SHONG On 2nd Mar 2004 (SOS#20463)
         Lottable01       NVARCHAR(18) NULL, -- NJOW01
         Altsku           NVARCHAR(20) NULL,  -- NJOW02
         SortBySkuLoc     INT        NULL,    --(CS01)
         Linenum          INT)
                         
        
   --(CS01) - START
   SELECT Storerkey,
          SortBySkuLoc  = ISNULL(MAX(CASE WHEN Code = 'SortBySkuLoc'  THEN 1 ELSE 0 END),0)
   INTO #TMP_RPTCFG
   FROM CODELKUP WITH (NOLOCK)
   WHERE ListName = 'REPORTCFG'
   AND Long      = 'r_dw_print_pickorder90'
   AND (Short IS NULL OR Short <> 'N')
   GROUP BY Storerkey
   --(CS01) - END                    
                         
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
             Lottable03,        Lottable01,       Altsku,SortBySkuLoc,Linenum) --NJOW01   --CS01

        SELECT DISTINCT 
        (SELECT PICKHEADERKEY FROM PICKHEADER (NOLOCK) 
            WHERE ExternOrderKey = @c_LoadKey 
            AND OrderKey = Orders.OrderKey 
            AND ZONE = '3'), 
        @c_LoadKey as LoadKey,                 
        Orders.OrderKey,                            
         -- SOS82873 Change company info from MBOL level to LOAD level
         -- NOTE: In ECCO case,2 style, the English information saved in C_company, C_Address�and Chinese Information saved in B_company,B_Address
        (CASE WHEN StorerConfig.sValue = '1' THEN IsNull(ORDERS.CONSIGNEEKEY , '')
        ELSE IsNull(ORDERS.BillToKey , '')  END  ) as ConsigneeKey ,
        (CASE WHEN StorerConfig.sValue = '1' THEN IsNull(ORDERS.B_Company , '')
        ELSE IsNull(ORDERS.C_Company, '')  END  ) as Company  ,

        (CASE WHEN StorerConfig.sValue = '1' THEN IsNull(ORDERS.B_Address1 , '')
        ELSE IsNull(ORDERS.C_Address1, '')  END  ) as Addr1  ,

        (CASE WHEN StorerConfig.sValue = '1' THEN IsNull(ORDERS.B_Address2 , '')
        ELSE IsNull(ORDERS.C_Address2, '')  END  ) as Addr2  ,
        0 AS PgGroup,                                       
        (CASE WHEN StorerConfig.sValue = '1' THEN IsNull(ORDERS.B_Address3 , '')
        ELSE IsNull(ORDERS.C_Address3, '')  END  ) as Addr3,
        IsNull(ORDERS.C_Zip,'') AS PostCode,
        IsNull(ORDERS.Route,'') AS Route,         
        IsNull(RouteMaster.Descr, '') Route_Desc,       
        ORDERS.Door AS TrfRoom,
        CONVERT(NVARCHAR(60), IsNull(ORDERS.Notes,  '')) Notes1,                                    
        0 AS RowNo, 
        CONVERT(NVARCHAR(60), IsNull(ORDERS.Notes2, '')) Notes2,
        PickDetail.loc,   
        PickDetail.sku,                         
        IsNULL(Sku.Descr,'') SkuDescr,                  
        SUM(PickDetail.qty) as Qty,
        0 AS TEMPQTY1,
        TempQty2 = 
          CASE WHEN pack.pallet = 0 then 0
                ELSE CASE WHEN (Sum(pickdetail.qty) % CAST(pack.pallet AS INT)) > 0 THEN 0
        ELSE 1 END END , -- Vicky
        IsNull((SELECT Distinct 'Y' FROM PickHeader (NOLOCK) WHERE ExternOrderKey = @c_LoadKey AND  Zone = '3'), 'N') AS PrintedFlag, 
        '3' Zone,
        Pickdetail.Lot,                         
        '' CarrierKey,                                  
        '' AS VehicleNo,
        LotAttribute.Lottable02,                
        IsNull(LotAttribute.Lottable04, '19000101') Lottable04,        
        '',--IsNull(LotAttribute.Lottable05, '19000101') Lottable05,   --WL01     
        PACK.Pallet,
        PACK.CaseCnt, 
        ORDERS.ExternOrderKey AS ExternOrderKey,               
        IsNuLL(LOC.LogicalLocation, '') AS LogicalLocation, 
        IsNull(AreaDetail.AreaKey, '00') AS Areakey,              -- Added By YokeBeen on 05-Mar-2002 (Ticket # 3377)
          IsNull (CONVERT(NVARCHAR(10), ORDERS.DeliveryDate, 103), ''), -- Added by MaryVong on 29-Dec-2003 (FBR#18681)
        LotAttribute.Lottable03, -- Added By SHONG On 2nd Mar 2004 (SOS#20463)  
        LotAttribute.Lottable01, -- NJOW01
        CASE WHEN ISNULL(SC.Svalue,'0') = '1' THEN --NJOW02 
             Sku.Altsku 
        ELSE 'NOSHOW' END AS ALTSKU
         ,  ISNULL(SortBySkuLoc,0)              --(CS01)
       , Linenum =  0 --CAST((Row_Number() OVER (PARTITION BY Orders.OrderKey ORDER BY PickDetail.Loc Asc)) AS nvarchar(5)) 
    FROM   LOADPLANDETAIL (NOLOCK) 
    JOIN ORDERS (NOLOCK) ON (ORDERS.Orderkey = LoadPlanDetail.Orderkey)
    JOIN Storer (NOLOCK) ON (ORDERS.StorerKey = Storer.StorerKey)
    JOIN OrderDetail (NOLOCK) ON (OrderDetail.OrderKey = ORDERS.OrderKey)     -- Added By YokeBeen on 18-Mar-2002 (Ticket # 2539)
    LEFT OUTER JOIN StorerConfig ON (ORDERS.StorerKey = StorerConfig.StorerKey AND StorerConfig.ConfigKey = 'UsedBillToAddressForPickSlip')
    LEFT OUTER JOIN RouteMaster ON (RouteMaster.Route = ORDERS.Route)
    JOIN PickDetail (NOLOCK) ON (PickDetail.OrderKey = LoadPlanDetail.OrderKey 
                    AND ORDERS.Orderkey = PICKDETAIL.Orderkey
                    AND ORDERDETAIL.Orderlinenumber = PICKDETAIL.Orderlinenumber)
    JOIN LotAttribute (NOLOCK) ON (PickDetail.Lot = LotAttribute.Lot)
    JOIN Sku (NOLOCK)  ON (Sku.StorerKey = PickDetail.StorerKey AND Sku.Sku = PickDetail.Sku AND SKU.Sku = OrderDetail.Sku)
    JOIN PACK (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
    JOIN LOC WITH (NOLOCK, INDEX (PKLOC)) ON (LOC.LOC = PICKDETAIL.LOC)
    LEFT OUTER JOIN AreaDetail (NOLOCK) ON (LOC.PutawayZone = AreaDetail.PutawayZone)
    LEFT OUTER JOIN Storerconfig SC (NOLOCK) ON (ORDERS.Storerkey = SC.Storerkey AND SC.Configkey = 'PICKORD01_SHOWALTSKU')  --NJOW02
    LEFT JOIN #TMP_RPTCFG RC ON (ORDERS.Storerkey = RC.Storerkey)        --(CS01)
   WHERE PickDetail.Status >= '0'  
       AND LoadPlanDetail.LoadKey = @c_LoadKey
     GROUP BY ORDERS.OrderKey,                            
        StorerConfig.sValue , 
        ORDERS.CONSIGNEEKEY,
        ORDERS.B_Company,
        ORDERS.B_Address1,
        ORDERS.B_Address2,
        ORDERS.B_Address3,
        ORDERS.BillToKey,
        ORDERS.C_Company,
        ORDERS.C_Address1,
        ORDERS.C_Address2,
        ORDERS.C_Address3,
        IsNull(ORDERS.C_Zip,''),
        IsNull(ORDERS.Route,''),
        IsNull(RouteMaster.Descr, ''),
        ORDERS.Door,
        CONVERT(NVARCHAR(60), IsNull(ORDERS.Notes,  '')),                                    
        CONVERT(NVARCHAR(60), IsNull(ORDERS.Notes2, '')),
        PickDetail.loc,   
        PickDetail.sku,    
        IsNULL(Sku.Descr,''),                  
        Pickdetail.Lot,                         
        LotAttribute.Lottable02,                
        IsNUll(LotAttribute.Lottable04, '19000101'),        
       -- IsNUll(LotAttribute.Lottable05, '19000101'),  
        PACK.Pallet,
        PACK.CaseCnt,
        ORDERS.ExternOrderKey,
        IsNull(LOC.LogicalLocation, ''),  
        IsNull(AreaDetail.AreaKey, '00'),     -- Added By YokeBeen on 05-Mar-2002 (Ticket # 3377)
        IsNull(CONVERT(NVARCHAR(10), ORDERS.DeliveryDate, 103), ''),    -- Added by MaryVong on 29-Dec-2003 (FBR#18681)
        LotAttribute.Lottable03, -- Added By SHONG On 2nd Mar 2004 (SOS#20463)
        LotAttribute.Lottable01, --NJOW01
        CASE WHEN ISNULL(SC.Svalue,'0') = '1' THEN --NJOW02 
             Sku.Altsku 
        ELSE 'NOSHOW' END
        ,  ISNULL(SortBySkuLoc,0)              --(CS01)


        
     BEGIN TRAN  

     -- Uses PickType as a Printed Flag  
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
         INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)
             SELECT 'P' + RIGHT ( REPLICATE ('0', 9) + 
             dbo.fnc_LTrim( dbo.fnc_RTrim( STR( CAST(@c_pickheaderkey AS int) + 
                              ( select count(distinct orderkey) 
                                from #TEMP_PICK as Rank 
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
     END
   
    DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
       select DISTINCT PickSlipNo,loadkey,orderkey,externorderkey,sku,--MIN(linenum)
       (Row_Number() OVER (PARTITION BY PickSlipNo,loadkey,orderkey,externorderkey ORDER BY sku Asc))
       from #TEMP_PICK  
       group by PickSlipNo,loadkey,orderkey,externorderkey,sku
       having count(distinct sku+loc) > 1   --WL01

       OPEN CUR_RESULT   
     
      FETCH NEXT FROM CUR_RESULT INTO @c_Pickslipno,  @c_Getloadkey  ,@c_Orderkey,@c_externorderkey,@c_sku,@n_line
     
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  

      Update #TEMP_PICK
      set linenum = @n_line
      where PickSlipNo = @c_Pickslipno
      and loadkey =@c_Getloadkey
      and orderkey =@c_Orderkey
      and externorderkey = @c_externorderkey
      and sku =@c_sku
     -- and linenum > @n_line
      
       FETCH NEXT FROM CUR_RESULT INTO @c_Pickslipno,  @c_Getloadkey  ,@c_Orderkey,@c_externorderkey,@c_sku,@n_line   
   END
   
   --WL01
   INSERT INTO #TEMP_SKU
   SELECT  ORDERKEY,   
           LOC,        
           SKU,        
           SkuDesc,    
           Areakey,    
           LogicalLoc, 
           Lottable02, 
           Lottable03, 
           Lottable04, 
           SUM(QTY),CASE WHEN packcasecnt > 0 THEN FLOOR(SUM(Qty)/packcasecnt) ELSE 0 END,SUM(QTY) 
           - (CASE WHEN packcasecnt > 0 THEN FLOOR(SUM(Qty)/packcasecnt) ELSE 0 END * packcasecnt )
   FROM #TEMP_PICK     
   GROUP BY ORDERKEY,   
           LOC,        
           SKU,        
           SkuDesc,    
           Areakey,    
           LogicalLoc, 
           Lottable02, 
           Lottable03, 
           Lottable04,
           packcasecnt

   --SELECT * FROM #TEMP_SKU
     GOTO SUCCESS
 FAILURE:
     DELETE FROM #TEMP_PICK
 SUCCESS: --WL01 
   SELECT P.*, S.Carton, S.Each
         ,(SELECT SUM(Carton) FROM #TEMP_SKU S WHERE S.ORDERKEY = P.OrderKey AND S.Areakey = P.Areakey) As SumCarton
         ,(SELECT SUM(Each) FROM #TEMP_SKU S WHERE S.ORDERKEY = P.OrderKey AND S.Areakey = P.Areakey) As Each
   FROM #TEMP_PICK P
   JOIN #TEMP_SKU S ON S.ORDERKEY = P.OrderKey AND S.LOC = P.LOC AND S.SKU = P.SKU AND S.SkuDesc = P.SkuDesc AND S.Areakey = P.Areakey
                   AND S.LogicalLoc = P.LogicalLoc AND S.Lottable02 = P.Lottable02 AND S.Lottable03 = P.Lottable03 AND S.Lottable04 = P.Lottable04
                   
      --(CS01) - START
   ORDER BY P.Orderkey
         ,  Company
         ,  P.areakey
         ,  tempqty2 DESC
         ,  P.LogicalLoc
         ,  CASE WHEN SortBySkuLoc = 1 THEN P.Sku ELSE '' END
         ,  CASE WHEN SortBySkuLoc = 1 THEN P.loc ELSE '' END
         ,  CASE WHEN SortBySkuLoc = 0 THEN P.Loc ELSE '' END    --CS02   --CM01
         ,  CASE WHEN SortBySkuLoc = 0 THEN P.Sku ELSE '' END    --CS02   --CM01
         ,  P.Lottable02
         ,  UOM
   --(CS01) - END
     
     DROP Table #TEMP_PICK  
 END


GO