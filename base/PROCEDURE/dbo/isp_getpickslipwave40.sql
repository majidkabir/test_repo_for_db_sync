SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_GetPickSlipWave40                              */
/* Creation Date: 20-Sept-2022                                          */
/* Copyright: IDS                                                       */
/* Written by: CHONGCS                                                  */
/*                                                                      */
/* Purpose:WMS-20738 [TW]PNG_PickingSlip_Report CR                      */
/*                                                                      */
/* Called By: r_dw_print_wave_pickslip_40                               */
/*           duplicate by r_dw_print_wave_pickslip_05_1                 */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 20-09-2022   CHONGCS 1.0   Devops Scripts Combine                    */
/************************************************************************/

CREATE   PROC [dbo].[isp_GetPickSlipWave40] (
   @c_wavekey NVARCHAR(10)
)
AS

BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE
   @c_pickheaderkey    NVARCHAR(10),
   @n_continue         int,
   @c_errmsg           NVARCHAR(255),
   @b_success          int,
   @n_err              int,
   @c_sku              NVARCHAR(20),
   @n_qty              int,
   @c_loc              NVARCHAR(10),
   @n_cases            int,
   @n_perpallet        int,
   @c_orderkey         NVARCHAR(10),
   @c_storer           NVARCHAR(15),
   @c_storercompany    NVARCHAR(45),
   @c_ConsigneeKey     NVARCHAR(15),
   @c_Company          NVARCHAR(45),
   @c_Addr1            NVARCHAR(45),
   @c_Addr2            NVARCHAR(45),
   @c_Addr3            NVARCHAR(45),
   @c_PostCode         NVARCHAR(15),
   @c_Route            NVARCHAR(10),
   @c_Route_Desc       NVARCHAR(60), -- RouteMaster.Desc
   @c_TrfRoom          NVARCHAR(10), -- ORDERS.Door Change by shong FBR7632
   @c_Notes1           NVARCHAR(60),
   @c_Notes2           NVARCHAR(60),
   @c_SkuDesc          NVARCHAR(60),
   @n_CaseCnt          int,
   @n_PalletCnt        int,
   @n_InnerPack        int,
   @c_ReceiptTm        NVARCHAR(20),
   @c_PrintedFlag      NVARCHAR(1),
   @c_UOM              NVARCHAR(10),
   @n_UOM3             int,
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
   @c_Lottable02       NVARCHAR(18),
   @c_Lottable03       NVARCHAR(18),
   @d_Lottable04       datetime,
   @c_labelPrice       NVARCHAR(5),
   @c_externorderkey   NVARCHAR(50),   --tlting_ext
   @c_externpokey      NVARCHAR(20),
   @c_invoiceno        NVARCHAR(10),
   @d_deliverydate     datetime,
   @c_rdd              NVARCHAR(10),
   @c_putawayzone      NVARCHAR(10),
   @c_zonedesc         NVARCHAR(60),
   @c_busr8            NVARCHAR(30), 
   @n_StartTCnt        int,
   @c_OVAS             NVARCHAR(30),
   @c_fullpallet       NVARCHAR(5), 
   @c_RetailSku        NVARCHAR(20), 
   @c_ID               NVARCHAR(18), 
   @c_ShowID           NVARCHAR(10), 
   @c_Buyerpo          NVARCHAR(20)  

SET @n_StartTCnt=@@TRANCOUNT

DECLARE
   @c_PrevOrderKey     NVARCHAR(10),
   @n_Pallets          int,
   @n_Cartons          int,
   @n_Eaches           int,
   @n_UOMQty           int,
   @n_SkuxLocQty       int,
   @n_TotalCubic       int,
   @n_TraceFlag        Int
  ,@c_PickZoneCfg NVARCHAR(10)           
  ,@c_puom02        NVARCHAR(10)           

CREATE TABLE #temp_pick (
   PickSlipNo       NVARCHAR(10),
   wavekey          NVARCHAR(10),
   OrderKey         NVARCHAR(10),
   ConsigneeKey     NVARCHAR(15) NULL,
   Company          NVARCHAR(45) NULL,
   Addr1            NVARCHAR(45) NULL,
   Addr2            NVARCHAR(45) NULL,
   Addr3            NVARCHAR(45) NULL,
   PostCode         NVARCHAR(15) NULL,
   Route            NVARCHAR(10) NULL,
   Route_Desc       NVARCHAR(60) NULL, -- RouteMaster.Desc
   TrfRoom          NVARCHAR(10) NULL, -- wave.TrfRoom
   Notes1           NVARCHAR(60) NULL,
   Notes2           NVARCHAR(60) NULL,
   LOC              NVARCHAR(10) NULL,
   SKU              NVARCHAR(20) NULL,
   SkuDesc          NVARCHAR(60) NULL,
   Qty              int,
   TempQty1         int,
   TempQty2         int,
   PrintedFlag      NVARCHAR(1),
   Zone             NVARCHAR(1),
   PgGroup          int,
   RowNum           int,
   Lot              NVARCHAR(10),
   Carrierkey       NVARCHAR(60) NULL,
   VehicleNo        NVARCHAR(10) NULL,
   Lottable02       NVARCHAR(18) NULL,
   Lottable04       datetime NULL,
   LabelPrice       NVARCHAR(5) NULL,
   ExternOrderKey   NVARCHAR(45) NULL,
   ExternPOKey      NVARCHAR(20) NULL,
   InvoiceNo        NVARCHAR(10) NULL,
   DeliveryDate     datetime NULL,
   PendingFlag      NVARCHAR(10) NULL,
   Storerkey        NVARCHAR(15) NULL,
   StorerCompany    NVARCHAR(45) NULL,
   CaseCnt          int NULL,
   Putawayzone      NVARCHAR(10) NULL,
   ZoneDesc         NVARCHAR(60) NULL,
   Innerpack        int NULL,
   Busr8            NVARCHAR(30) NULL,
   Lottable03       NVARCHAR(18) NULL,
   TotalCubic       int NULL,
   LogicalLoc       NVARCHAR(18) NULL,
   OVAS             NVARCHAR(30) NULL,
   FullPallet       NVARCHAR(5) NULL, 
   RetailSKU        NVARCHAR(20) NULL,
   PUOM02           NVARCHAR(10),   
   ID               NVARCHAR(18),     
   ShowID           NVARCHAR(10),     
   Buyerpo          NVARCHAR(20) NULL)



SELECT @n_continue = 1
SELECT @n_RowNo = 0
SELECT @c_firstorderkey = 'N'
SELECT @n_TraceFlag = 0

SET @c_PickZoneCfg   = ''     
SET @c_Retailsku = ''     

-- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 8 - By Order
IF EXISTS(SELECT 1 FROM PickHeader (NOLOCK) WHERE Wavekey = @c_wavekey AND Zone = '8')
BEGIN
   SELECT @c_firsttime = 'N'
   SELECT @c_PrintedFlag = 'Y'
END
ELSE
BEGIN
   SELECT @c_firsttime = 'Y'
   SELECT @c_PrintedFlag = 'N'
END -- Record Not Exists

WHILE @@TRANCOUNT > 0
   COMMIT TRAN

-- Uses PickType as a Printed Flag
IF @c_firsttime = 'N'
BEGIN
   BEGIN TRAN

   UPDATE PickHeader
   SET PickType = '1',
       TrafficCop = NULL
   WHERE WaveKey = @c_wavekey
   AND Zone = '8'
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
         GOTO QUIT
      END
   END
END

SELECT P.Loc, P.Storerkey, P.Sku,  
       LA.Lottable03, LA.Lottable02, LA.Lottable04,
       CASE WHEN PACK.Pallet > 0 THEN
            CASE WHEN SUM(P.Qty) % CAST(PACK.Pallet AS INT) = 0 AND MAX(ISNULL(P.Taskdetailkey,'')) <> '' 
                 AND ISNULL(W.UserDefine01,'') = '' AND LOC.Pickzone = 'B' AND ISNULL(CLR.Code,'') <> '' THEN
             'FP' ELSE '' END 
       ELSE '' END AS FullPallet,
       O.Orderkey 
INTO #TMP_PICKTYPE     
FROM WAVE W (NOLOCK)  
JOIN WAVEDETAIL WD (NOLOCK) ON W.Wavekey = WD.Wavekey 
JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey 
JOIN PICKDETAIL P (NOLOCK) ON O.Orderkey = P.Orderkey 
JOIN SKU S (NOLOCK) ON P.Storerkey = S.Storerkey AND P.Sku = S.Sku 
JOIN PACK (NOLOCK) ON S.Packkey = PACK.Packkey 
JOIN LOC (NOLOCK) ON P.Loc = LOC.Loc 
JOIN LOTATTRIBUTE LA (NOLOCK) ON P.Lot = LA.Lot 
LEFT JOIN Codelkup CLR (NOLOCK) ON (O.Storerkey = CLR.Storerkey AND CLR.Code = 'SHOWFULLPLT' 
                                    AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_print_wave_pickslip_40' AND ISNULL(CLR.Short,'') <> 'N')
WHERE W.Wavekey = @c_wavekey 
AND P.Status < '5'
AND (P.Pickmethod = '8' OR P.Pickmethod = ' ')
GROUP BY P.Loc, LOC.Pickzone, P.Storerkey, P.Sku,  
         LA.Lottable02, LA.Lottable03, LA.Lottable04, PACK.Casecnt,  
         PACK.Pallet, ISNULL(W.UserDefine01,''), ISNULL(CLR.Code,''),
         O.Orderkey 

DECLARE pick_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT PickDetail.sku,       PickDetail.loc,
       SUM(PickDetail.qty),  PACK.Qty,
       PickDetail.storerkey, PickDetail.OrderKey,
       PickDetail.UOM,       LOC.LogicalLocation,
       LA.Lottable02,        LA.Lottable03,
       LA.Lottable04,       (SUM(PickDetail.qty) * SKU.STDCUBE),
       CASE WHEN ISNULL(CL.Code,'') <> '' THEN
       SKU.OVAS ELSE '' END AS OVAS,
       ISNULL(PT.FullPallet,'') AS FullPallet, 
       CASE WHEN CS.B_Company = 'YFY' THEN SKU.RetailSKU ELSE '' END AS RetailSku,    
       CASE WHEN ISNULL(CL1.Short,'N') = 'Y' THEN PickDetail.ID ELSE '' END AS ID,    
       ISNULL(CL1.Short,'N') AS ShowID                                               
FROM   PickDetail (NOLOCK)
JOIN   Wavedetail (NOLOCK) ON (PickDetail.OrderKey = Wavedetail.OrderKey)
JOIN   PACK (NOLOCK) ON (PickDetail.Packkey = PACK.Packkey)
JOIN   LOC (NOLOCK) ON (LOC.Loc = PICKDETAIL.Loc)
JOIN   ORDERS (NOLOCK) ON (ORDERS.Orderkey = WaveDetail.Orderkey AND
         ORDERS.Orderkey = PICKDETAIL.Orderkey)
JOIN   SKU (NOLOCK) ON (SKU.SKU = PICKDETAIL.SKU AND
                        SKU.Storerkey = PICKDETAIL.Storerkey)
JOIN   LotAttribute LA (NOLOCK) ON (PickDetail.LOT = LA.LOT) 
LEFT JOIN STORER CS (NOLOCK) ON (ORDERS.Consigneekey = CS.Storerkey)
LEFT JOIN CODELKUP CL (NOLOCK) ON (PickDetail.Storerkey = CL.Storerkey AND CL.UDF01='OVAS' AND CL.Listname='SECONDARY' AND CS.Secondary = CL.Code)
LEFT JOIN #TMP_PICKTYPE PT (NOLOCK) ON (PickDetail.Storerkey = PT.Storerkey AND PickDetail.Sku = PT.Sku AND LOC.Loc = PT.Loc 
                                    AND LA.Lottable02 = PT.Lottable02 AND LA.Lottable03 = PT.Lottable03 
                                    AND LA.Lottable04 = PT.Lottable04 AND Pickdetail.Orderkey = PT.Orderkey) 
LEFT JOIN CODELKUP CL1 (NOLOCK) ON CL1.LISTNAME = 'REPORTCFG' AND CL1.CODE = 'ShowPickDetailID'  
                               AND CL1.Long = 'r_dw_print_wave_pickslip_05'                   
                               AND CL1.Storerkey = ORDERS.StorerKey                       
WHERE PickDetail.Status < '5'
AND    Wavedetail.Wavekey = @c_wavekey
AND    (PICKDETAIL.Pickmethod = '8' OR PICKDETAIL.Pickmethod = ' ')-- user wants it to be on lists
GROUP BY PickDetail.sku,  PickDetail.loc, PACK.Qty,
PickDetail.storerkey, PickDetail.OrderKey, PICKDETAIL.UOM,
LOC.LogicalLocation, LA.Lottable02, LA.Lottable04, LA.Lottable03, SKU.STDCUBE, 
CASE WHEN ISNULL(CL.Code,'') <> '' THEN
         SKU.OVAS ELSE '' END ,
ISNULL(PT.FullPallet,''), 
CASE WHEN CS.B_Company = 'YFY' THEN SKU.RetailSKU ELSE '' END,                
CASE WHEN ISNULL(CL1.Short,'N') = 'Y' THEN PickDetail.ID ELSE '' END,    
ISNULL(CL1.Short,'N')                                                   
ORDER BY PICKDETAIL.ORDERKEY

OPEN pick_cur

SELECT @c_PrevOrderKey = ''
FETCH NEXT FROM pick_cur INTO @c_sku, @c_loc, @n_Qty, @n_uom3, @c_storerkey,
                              @c_orderkey,  @c_UOM, @c_logicalloc, @c_Lottable02, @c_Lottable03, @d_Lottable04, @n_TotalCubic, @c_OVAS,
                              @c_FullPallet,@c_Retailsku, 
                              @c_ID, @c_ShowID  

WHILE (@@FETCH_STATUS <> -1)
BEGIN --While

   IF @c_OrderKey <> @c_PrevOrderKey
   BEGIN

      IF @n_TraceFlag = 1
      BEGIN
         INSERT INTO TraceInfo (TraceName, TimeIn, Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5)
         SELECT 'isp_GetPickSlipWave40', GetDate(), @c_wavekey, OrderKey, OrderLineNumber, Lot, Loc, Id, Sku, StorerKey, PickDetailKey, Suser_Sname()
         FROM PickDetail WITH (NOLOCK)
         WHERE OrderKey = @c_OrderKey
         And StorerKey = @c_storerkey
      END

      IF NOT EXISTS( SELECT 1 FROM PICKHEADER (NOLOCK) WHERE WaveKey = @c_wavekey AND OrderKey = @c_OrderKey AND ZONE = '8')
      BEGIN  --Not Exist in PickHeader
         EXECUTE nspg_GetKey
                  'PICKSLIP',
                  9,
                  @c_pickheaderkey  OUTPUT,
                  @b_success        OUTPUT,
                  @n_err            OUTPUT,
                  @c_errmsg         OUTPUT

         SELECT @c_pickheaderkey = 'P' + @c_pickheaderkey

         BEGIN TRAN

         INSERT INTO PICKHEADER
            (PickHeaderKey, OrderKey, WaveKey, PickType, Zone, TrafficCop)
         VALUES
            (@c_pickheaderkey, @c_OrderKey, @c_wavekey, '0', '8', '')

         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            ROLLBACK TRAN
            GOTO QUIT
         END
         ELSE
         BEGIN
            WHILE @@TRANCOUNT > 0
               COMMIT TRAN
         END

         SELECT @c_firstorderkey = 'Y'
      END  --NOT EXIST in PICKHEADER
      ELSE
      BEGIN -- EXIST in PickHeader
         SELECT @c_pickheaderkey = PickHeaderKey
         FROM  PickHeader (NOLOCK)
         WHERE WaveKey = @c_wavekey
         AND   Zone = '8'
         AND   OrderKey = @c_OrderKey
      END -- Exist in PickHeader
   END  -- @c_OrderKey <> @c_PrevOrderKey
   IF ISNULL(RTRIM(@c_OrderKey),'') = '' --dbo.fnc_RTrim(@c_OrderKey) = '' OR dbo.fnc_RTrim(@c_OrderKey) IS NULL
   BEGIN  --if @c_orderkey = ''
      SELECT @c_ConsigneeKey = '',
            @c_Company = '',
            @c_Addr1 = '',
            @c_Addr2 = '',
            @c_Addr3 = '',
            @c_PostCode = '',
            @c_Route = '',
            @c_Route_Desc = '',
            @c_Notes1 = '',
            @c_Notes2 = ''
   END  --if @c_orderkey=''
   ELSE
   BEGIN --if @c_orderkey <> ''
      SELECT @c_ConsigneeKey  = Orders.Consigneekey,
            @c_Company        = ORDERS.c_Company,
            @c_Addr1          = ISNULL(ORDERS.C_City,'') + ISNULL(ORDERS.C_Address1,''), 
            @c_Addr2          = ORDERS.C_Address2,
            @c_Addr3          = ORDERS.C_Address3,
            @c_PostCode       = ORDERS.C_Zip,
            @c_Notes1         = CONVERT(NVARCHAR(60), ORDERS.Notes),
            @c_Notes2         = CONVERT(NVARCHAR(60), ORDERS.Notes2),
            @c_labelprice     = ISNULL(ORDERS.LabelPrice, 'N'),
            @c_route          = ORDERS.Route,
            @c_externorderkey = RTRIM(ExternOrderKey)+' ('+RTRIM(type)+')' ,
            @c_trfRoom        = ORDERS.Door,
            @c_externpokey    = ORDERS.ExternPoKey,
            @c_InvoiceNo      = ORDERS.InvoiceNo,
            @d_DeliveryDate   = ORDERS.DeliveryDate,
            @c_rdd            = ORDERS.RDD,
            @c_Buyerpo        = ORDERS.buyerpo  
      FROM   ORDERS (NOLOCK)
      WHERE  ORDERS.OrderKey = @c_OrderKey
   END -- IF @c_OrderKey <> ''


   SELECT @c_Route_Desc  = ISNULL(RTRIM(RouteMaster.Descr), '')
   FROM   RouteMaster (NOLOCK)
   WHERE  Route = @c_Route

   SELECT @c_SkuDesc = ISNULL(RTRIM(Descr),''),
          @c_busr8 = ISNULL(RTRIM(Busr8), '')
   FROM   SKU  (NOLOCK)
   WHERE  STorerKey = @c_StorerKey
   AND    SKU = @c_SKU

   SELECT @c_storercompany = ISNULL(RTRIM(Company), '')
   FROM  STORER (NOLOCK)
   WHERE STORERKEY = @c_storerkey

   SELECT @c_PickZoneCfg = ISNULL(RTRIM(SValue),'')
   FROM StorerConfig WITH (NOLOCK) 
   WHERE Storerkey = @c_Storerkey
   AND   Configkey = 'WavePS05_PickZone'


   SELECT @c_putawayzone = CASE @c_PickZoneCfg WHEN '1' THEN ISNULL(RTRIM(LOC.PickZone), '')       
                                                        ELSE ISNULL(RTRIM(LOC.Putawayzone), '')   
                                                        END,                                     
          @c_zonedesc = ISNULL(RTRIM(PUTAWAYZONE.Descr), '')
   FROM   LOC (nolock), PUTAWAYZONE (nolock)
   WHERE  PUTAWAYZONE.PUTAWAYZONE = LOC.PUTAWAYZONE
   AND    LOC.LOC = @c_loc

   IF @c_Lottable02    IS NULL SELECT @c_Lottable02 = ''
   IF @c_Lottable03    IS NULL SELECT @c_Lottable03 = ''
   IF @d_Lottable04    IS NULL SELECT @d_Lottable04 = '01/01/1900'
   IF @c_Notes1        IS NULL SELECT @c_Notes1 = ''
   IF @c_Notes2        IS NULL SELECT @c_Notes2 = ''
   IF @c_ConsigneeKey  IS NULL SELECT @c_ConsigneeKey = ''
   IF @c_Company       IS NULL SELECT @c_Company = ''
   IF @c_Addr1         IS NULL SELECT @c_Addr1 = ''
   IF @c_Addr2         IS NULL SELECT @c_Addr2 = ''
   IF @c_Addr3         IS NULL SELECT @c_Addr3 = ''
   IF @c_PostCode      IS NULL SELECT @c_PostCode = ''
   IF @c_Route         IS NULL SELECT @c_Route = ''
   IF @c_CarrierKey    IS NULL SELECT @c_Carrierkey = ''
   IF @c_Route_Desc    IS NULL SELECT @c_Route_Desc = ''
   IF @c_superorderflag = 'Y' SELECT  @c_orderkey = ''

   SELECT @n_RowNo = @n_RowNo + 1
   SELECT @n_Pallets = 0,
          @n_Cartons = 0,
          @n_Eaches  = 0
   SELECT @n_UOMQty = 0
   SELECT @n_UOMQty = CASE @c_UOM
                        WHEN '1' THEN PACK.Pallet
                        WHEN '2' THEN PACK.CaseCnt
                        WHEN '3' THEN PACK.InnerPack
                        ELSE 1
                      END,
          @n_CaseCnt = CaseCnt,
          @n_InnerPack = Pack.InnerPack
          ,@c_PUOM02 = PACK.Packuom2            
   FROM   PACK (NOLOCK), SKU (NOLOCK)
   WHERE  SKU.StorerKey = @c_StorerKey
   AND    SKU.SKU = @c_SKU
   AND    PACK.PackKey = SKU.PackKey

   INSERT INTO #Temp_Pick
   (PickSlipNo,         wavekey,          OrderKey,         ConsigneeKey,
    Company,            Addr1,            Addr2,            PgGroup,
    Addr3,              PostCode,         Route,            Route_Desc,
    TrfRoom,            Notes1,           RowNum,           Notes2,
    LOC,                SKU,              SkuDesc,          Qty,
    TempQty1,           TempQty2,         PrintedFlag,      Zone,
    Lot,                CarrierKey,       VehicleNo,        Lottable02,
    Lottable04,         LabelPrice,       ExternOrderKey,   ExternPoKey,
    InvoiceNo,          DeliveryDate,     PendingFlag,      Storerkey,
    StorerCompany,      CaseCnt,          Putawayzone,      ZoneDesc,
    InnerPack,          Busr8,            Lottable03,       TotalCubic,
    LogicalLoc,         OVAS,             FullPallet, RetailSku ,PUOM02,     
    ID,                 ShowID,           Buyerpo          ) 
   VALUES
   (@c_pickheaderkey,    @c_wavekey,       @c_OrderKey,      @c_ConsigneeKey,
    @c_Company,          @c_Addr1,         @c_Addr2,         0,
    @c_Addr3,            @c_PostCode,      @c_Route,         @c_Route_Desc,
    @c_TrfRoom,          @c_Notes1,        @n_RowNo,         @c_Notes2,
    @c_LOC,              @c_SKU,           @c_SKUDesc,       @n_Qty,
    CAST(@c_UOM as int), @n_UOMQty,        @c_PrintedFlag,   '8',
    '',                  @c_Carrierkey,    @c_VehicleNo,     @c_Lottable02,
    @d_Lottable04,       @c_labelprice,    @c_externorderkey, @c_ExternPoKey,
    @c_invoiceno,        @d_deliverydate,  @c_rdd,           @c_storerkey,
    @c_storercompany,    @n_CaseCnt,       @c_putawayzone,   @c_ZoneDesc,
    @n_innerpack,        @c_busr8,         @c_Lottable03,    @n_TotalCubic,
    @c_logicalloc,       @c_OVAS,          @c_FullPallet,@c_retailsku,@c_puom02,  
    @c_ID,               @c_ShowID,        @c_buyerpo)

   SELECT @c_PrevOrderKey = @c_OrderKey

   FETCH NEXT FROM pick_cur INTO @c_sku, @c_loc, @n_Qty, @n_uom3, @c_storerkey,
                                 @c_orderkey, @c_UOM, @c_logicalloc, @c_Lottable02, @c_Lottable03, @d_Lottable04, @n_TotalCubic, @c_OVAS,
                                 @c_FullPallet,@c_Retailsku, 
                                 @c_ID, @c_ShowID  
END

CLOSE pick_cur
DEALLOCATE pick_cur

WHILE @@TRANCOUNT > 0
         COMMIT TRAN

SELECT * FROM #temp_pick

ORDER BY Orderkey
      ,  Putawayzone
      ,  CASE WHEN @c_PickZoneCfg = '1' AND Putawayzone = 'P' THEN Putawayzone
              WHEN @c_PickZoneCfg = '1' AND Putawayzone <>'P' THEN Sku 
              ELSE Putawayzone END
      ,  LogicalLoc
      ,  Loc


QUIT:
   TRUNCATE Table #temp_pick

   WHILE @@TRANCOUNT < @n_StartTCnt
      BEGIN TRAN

   /* #INCLUDE <SPTPA01_2.SQL> */
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT > @n_StartTCnt
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_GetPickSlipWave40'
      -- RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN

         COMMIT TRAN
      END
      RETURN
   END
END

GO