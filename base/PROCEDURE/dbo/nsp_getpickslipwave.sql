SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

-- Modification History
-- For Phase 3 Customisation..
-- Added new columns into Result Set
-- 1) BUSR8 (Poison Flag)

-- Ignore this portion..
-- -- SOS Ticket 7002, To able user to to reprint pick slip with searching by detailed 
-- -- searching parameter such as Warehouse Order or Ext Order Number to reduce the unnecessary wastages.
-- -- Modify by SHONG 04-10-2002
-- Modified by Jeff - 12 Nov 2002 - Manual picks have pickmethod = ' '. We want to include that in the pick slip.

/************************************************************************/
/* Stored Procedure: nsp_GetPickSlipWave                                */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1 (Unicode)                                          */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 08-May-2006  June          SOS49892 - ECCO HK Manual Order interface */
/*                            to WMS01                                  */
/* 30-Aug-2006  June          SOS57251 - Loreal HK add Sku.AltSKU &     */
/*                            Storer.Susr2                              */
/* 24-Jul-2008  Leong         SOS# 111204 - Order by LOC.LogicalLocation*/
/* 01-Aug-2008  YTWan   1.1   SOS#285139  - Vitec_Pickslip(Wan01)       */
/* 17-Jan-2017  CSCHONG 1.2   WMS-954 - Add new field (CS01)            */
/* 28-Jan-2019  TLTING_ext 1.3 enlarge externorderkey field length      */
/************************************************************************/

CREATE PROC [dbo].[nsp_GetPickSlipWave] (
@c_wavekey          NVARCHAR(10)
-- @c_OrderKeyStart    NVARCHAR(10),
-- @c_OrderKeyEnd      NVARCHAR(10),
-- @c_ExtOrderKeyStart NVARCHAR(20),
-- @c_ExtOrderKeyEnd   NVARCHAR(20)
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
@c_TrfRoom          NVARCHAR(10),  -- ORDERS.Door Change by shong FBR7632
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
@c_Lottable02       NVARCHAR(18),
@c_Lottable03       NVARCHAR(18),
@d_Lottable04       datetime,
@c_labelPrice       NVARCHAR(5),
@c_externorderkey   NVARCHAR(50),  --tlting_ext
@c_externpokey      NVARCHAR(20),
@c_invoiceno        NVARCHAR(10),
@d_deliverydate     datetime,
@c_rdd              NVARCHAR(10),
@c_putawayzone      NVARCHAR(10),
@c_zonedesc         NVARCHAR(60),
@c_busr8            NVARCHAR(30),      -- Added by YokeBeen on 21-May-2002 (FBR107)
@c_AltSku           NVARCHAR(20),         -- SOS57251
@c_Susr2            NVARCHAR(20),         -- SOS57251
@n_StartTCnt        int,
@c_facility         NVARCHAR(1),          --(Wan01)
@c_WavePSlipQRCode  NVARCHAR(10),         --(Wan01)
@c_qrcode           NVARCHAR(1),          --(Wan01)
@c_showecomfield    NVARCHAR(1),          --(CS01)
@c_Trackingno       NVARCHAR(30),         --(CS01)
@c_Buyerpo          NVARCHAR(20)          --(CS01)

SET @n_StartTCnt=@@TRANCOUNT

DECLARE @c_PrevOrderKey     NVARCHAR(10),
        @n_Pallets          int,
        @n_Cartons          int,
        @n_Eaches           int,
        @n_UOMQty           int
                       
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
   TrfRoom          NVARCHAR(10) NULL,  -- wave.TrfRoom , Change by shong FBR7632
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
    ExternOrderKey  NVARCHAR(45) NULL,
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
   Busr8            NVARCHAR(30) NULL, -- Added by YokeBeen on 21-May-2002 (FBR107)
   Lottable03       NVARCHAR(18) NULL, -- Added by Shong 01-Jul-2002
   AltSKU           NVARCHAR(20) NULL, -- SOS57251
   SUSR2            NVARCHAR(20) NULL, -- SOS57251
   LogicalLocation  NVARCHAR(18) NULL  --SOS# 111204
,  WavePSlipQRCode  NVARCHAR(10) NULL  --(Wan01)
,  QRCode           NVARCHAR(1)  NULL  --(Wan01)
,  showecomfield    NVARCHAR(1) NULL   --(CS01)
,  Trackingno       NVARCHAR(30) NULL  --(CS01)
,  Buyerpo          NVARCHAR(20) NULL --(CS01)
   )

SELECT @n_continue = 1
SELECT @n_RowNo = 0
SELECT @c_firstorderkey = 'N'

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
-- Added BY SHONG, Only update when PickHeader Exists
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


DECLARE pick_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT PickDetail.sku,       PickDetail.loc,
       SUM(PickDetail.qty),  PACK.Qty,
       PickDetail.storerkey, PickDetail.OrderKey,
       PickDetail.UOM,       LOC.LogicalLocation,
       Pickdetail.Lot
FROM   PickDetail WITH (NOLOCK),  Wavedetail WITH (NOLOCK),
PACK WITH (NOLOCK), LOC WITH (NOLOCK), ORDERS WITH(NOLOCK)
WHERE  PickDetail.OrderKey = Wavedetail.OrderKey
AND    ORDERS.Orderkey = WaveDetail.Orderkey
AND    ORDERS.Orderkey = PICKDETAIL.Orderkey
AND    ORDERS.Userdefine08 = 'Y' -- only for wave plan orders.
--AND    PickDetail.Status < '5'
AND    PickDetail.Packkey = PACK.Packkey
AND    LOC.Loc = PICKDETAIL.Loc
AND    wavedetail.wavekey = @c_wavekey
AND    ( PICKDETAIL.Pickmethod = '8' OR PICKDETAIL.Pickmethod = ' ' )-- user wants it to be on lists
-- Ignore this portion..
-- -- Added BY SHONG 04-OCT-2002
-- AND   (ORDERS.OrderKey Between @c_OrderKeyStart AND @c_OrderKeyEnd)
-- AND   (ORDERS.ExternOrderKey Between @c_ExtOrderKeyStart AND @c_ExtOrderKeyEnd)
-- End
GROUP BY PickDetail.sku,  PickDetail.loc, PACK.Qty,
PickDetail.storerkey, PickDetail.OrderKey, PICKDETAIL.UOM,
LOC.LogicalLocation,  Pickdetail.Lot
ORDER BY PICKDETAIL.ORDERKEY, LOC.LogicalLocation --SOS# 111204 

OPEN pick_cur

SELECT @c_PrevOrderKey = ''
FETCH NEXT FROM pick_cur INTO @c_sku, @c_loc, @n_Qty, @n_uom3, @c_storerkey,
@c_orderkey,  @c_UOM, @c_logicalloc, @c_lot

WHILE (@@FETCH_STATUS <> -1)
BEGIN --While
   IF @c_OrderKey <> @c_PrevOrderKey
   BEGIN
      --(Wan01) -- START
      SET @c_facility= '' 
      SELECT @c_Facility = Facility
      FROM ORDERS WITH (NOLOCK)
      WHERE Orderkey = @c_OrderKey

      SET @b_success = 0
      SET @c_WavePSlipQRCode = ''
      EXECUTE nspGetRight
              @c_facility              -- Facility
            , @c_StorerKey             -- Storer
            , NULL                     -- No Sku in this Case
            , 'WavePSlip_QRCode'       -- ConfigKey
            , @b_success               OUTPUT 
            , @c_WavePSlipQRCode       OUTPUT 
            , @n_err                   OUTPUT 
            , @c_errmsg                OUTPUT

      IF @b_success <> 1
      BEGIN
         SET @n_continue = 3
         SET @n_err = 62701  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)
                          + ': Retrieve Failed On GetRight (WavePSlip_QRCode). (nsp_GetPickSlipWave)'
         GOTO QUIT
      END
      --(Wan01) -- END

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
         (PickHeaderKey,    OrderKey,    WaveKey, PickType, Zone, TrafficCop)
         VALUES
         (@c_pickheaderkey, @c_OrderKey, @c_wavekey,     '0',      '8',  '')
      
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
   IF dbo.fnc_RTRIM(@c_OrderKey) = '' OR dbo.fnc_RTRIM(@c_OrderKey) IS NULL
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
            @c_Notes2 = '',
            @c_Trackingno = '',  --(CS01)
            @c_Buyerpo = ''    --(CS01)
   END  --if @c_orderkey=''
   ELSE
   BEGIN --if @c_orderkey <> ''
      SELECT @c_ConsigneeKey = Orders.BillToKey,
            @c_Company      = ORDERS.c_Company,
            @c_Addr1        = ORDERS.C_Address1,
            @c_Addr2        = ORDERS.C_Address2,
            @c_Addr3        = ORDERS.C_Address3,
            @c_PostCode     = ORDERS.C_Zip,
            @c_Notes1       = CONVERT(NVARCHAR(60), ORDERS.Notes),
            @c_Notes2       = CONVERT(NVARCHAR(60), ORDERS.Notes2),
            @c_labelprice   = ISNULL( ORDERS.LabelPrice, 'N' ),
            @c_route        = ORDERS.Route,
            @c_externorderkey = dbo.fnc_RTRIM(ExternOrderKey)+' ('+dbo.fnc_RTRIM(type)+')' ,
            @c_trfRoom    = ORDERS.Door,
            @c_externpokey  = ORDERS.ExternPoKey,
            @c_InvoiceNo    = ORDERS.InvoiceNo,
            @d_DeliveryDate = ORDERS.DeliveryDate,
            @c_rdd           = ORDERS.RDD,
            @c_Trackingno = ISNULL(ORDERS.TrackingNo,''),              --(CS01)
            @c_Buyerpo  = ISNULL(ORDERS.BuyerPO,'')                    --(CS01)                                            
      FROM   ORDERS (NOLOCK)
      WHERE  ORDERS.OrderKey = @c_OrderKey
   END -- IF @c_OrderKey <> ''

   /*
   SELECT @c_TrfRoom   = IsNULL(wave.TrfRoom, ''),
   @c_Route     = IsNULL(wave.Route, ''),
   @c_VehicleNo = IsNULL(wave.TruckSize, ''),
   @c_Carrierkey = IsNULL(wave.CarrierKey,'')
   FROM   wave (NOLOCK)
   WHERE  wavekey = @c_wavekey
   */

   SELECT @c_Route_Desc  = IsNull(RouteMaster.Descr, '')
   FROM   RouteMaster (NOLOCK)
   WHERE  Route = @c_Route

   SELECT @c_SkuDesc = IsNULL(Descr,''),
          @c_busr8 = IsNULL(Busr8, '')
   FROM   SKU  (NOLOCK)
   WHERE  STorerKey = @c_StorerKey
   AND    SKU = @c_SKU

   SELECT @c_Lottable02 = Lottable02,
          @d_Lottable04 = Lottable04,
          @c_Lottable03 = Lottable03
   FROM   LOTATTRIBUTE (NOLOCK)
   WHERE  LOT = @c_LOT

   SELECT @c_storercompany = Company          
   FROM  STORER (NOLOCK)
   WHERE STORERKEY = @c_storerkey

   SELECT @c_putawayzone = LOC.Putawayzone,
          @c_zonedesc = PUTAWAYZONE.Descr
   FROM   LOC (nolock), PUTAWAYZONE (nolock)
   WHERE  PUTAWAYZONE.PUTAWAYZONE = LOC.PUTAWAYZONE 
   AND    LOC.LOC = @c_loc

   IF @c_Lottable02    IS NULL SELECT @c_Lottable02 = ''
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
   IF @c_superorderflag = 'Y' SELECT @c_orderkey = ''

   -- SOS57251
   SELECT @c_Susr2 = Susr2  
   FROM  STORER (NOLOCK)
   WHERE STORERKEY = @c_ConsigneeKey   
   
   SELECT @n_RowNo = @n_RowNo + 1
   SELECT @n_Pallets = 0,
         @n_Cartons = 0,
         @n_Eaches  = 0
   SELECT @n_UOMQty = 0

   SET @c_qrcode  = ''                             --(Wan01)
   SELECT @n_UOMQty = CASE @c_UOM
                        WHEN '1' THEN PACK.Pallet
                        WHEN '2' THEN PACK.CaseCnt
                        WHEN '3' THEN PACK.InnerPack
                        ELSE 1
                      END,
         @n_CaseCnt = CaseCnt,
         @n_InnerPack = Pack.InnerPack,
         @c_AltSku = AltSKU   -- SOS57251
        ,@c_Qrcode = ISNULL(RTRIM(SKU.Busr8),'')   --(Wan01)
   FROM   PACK (NOLOCK), SKU (NOLOCK)
   WHERE  SKU.StorerKey = @c_StorerKey
   AND    SKU.SKU = @c_SKU
   AND    PACK.PackKey = SKU.PackKey

   --(Wan01) - START
   SET @c_Qrcode = CASE WHEN @c_WavePSlipQRCode = '1' AND @c_Qrcode = '1' THEN 'Y'
                        WHEN @c_WavePSlipQRCode = '1' AND @c_Qrcode = '0' THEN 'N'
                        ELSE ' '
                        END 
   --(Wan01) - END
   
   /*CS01 Start*/
   SET @c_showecomfield = 'N'
   
	SELECT @c_showecomfield = ISNULL(MAX(CASE WHEN Code = 'SHOWECOMFIELD'  THEN 'Y' ELSE 'N' END),'N')   
   FROM CODELKUP WITH (NOLOCK)
   WHERE ListName = 'REPORTCFG'
   AND Long      = 'd_dw_print_wave_pickslip'
   AND (Short IS NULL OR Short <> 'N')
   AND Storerkey = @c_StorerKey
  /*CS01 END*/

   INSERT INTO #Temp_Pick
   (PickSlipNo,         wavekey,          OrderKey,         ConsigneeKey,
   Company,             Addr1,            Addr2,            PgGroup,
   Addr3,               PostCode,         Route,            Route_Desc,
   TrfRoom,             Notes1,           RowNum,           Notes2,
   LOC,                 SKU,              SkuDesc,          Qty,
   TempQty1,            TempQty2,         PrintedFlag,      Zone,
   Lot,                 CarrierKey,       VehicleNo,        Lottable02,
   Lottable04,          LabelPrice,       ExternOrderKey,   ExternPoKey,
   InvoiceNo,           DeliveryDate,     PendingFlag,      Storerkey,  
   StorerCompany,       CaseCnt,          Putawayzone,      ZoneDesc,   
   InnerPack,           Busr8,            Lottable03,
   AltSKU,              SUSR2, -- SOS57251
   LogicalLocation
   , WavePSlipQRCode   ,QRCode,showecomfield,Trackingno,Buyerpo   --(Wan01)  --(CS01) 
   ) -- SOS# 111204
   VALUES
   (@c_pickheaderkey,   @c_wavekey,       @c_OrderKey,      @c_ConsigneeKey,
   @c_Company,          @c_Addr1,         @c_Addr2,         0,
   @c_Addr3,            @c_PostCode,      @c_Route,         @c_Route_Desc,
   @c_TrfRoom,          @c_Notes1,        @n_RowNo,         @c_Notes2,
   @c_LOC,              @c_SKU,           @c_SKUDesc,       @n_Qty,
   CAST(@c_UOM as int), @n_UOMQty,        @c_PrintedFlag,   '8',
   @c_Lot,              @c_Carrierkey,    @c_VehicleNo,     @c_Lottable02,
   @d_Lottable04,       @c_labelprice,    @c_externorderkey, @c_ExternPoKey,
   @c_invoiceno,        @d_deliverydate,  @c_rdd,           @c_storerkey,  
   @c_storercompany,    @n_CaseCnt,       @c_putawayzone,   @c_ZoneDesc,   
   @n_innerpack,        @c_busr8,         @c_Lottable03,
   @c_AltSKU,           @c_Susr2, -- SOS57251
   @c_logicalloc
   , @c_WavePSlipQRCode,@c_QRCode                  --(Wan01) 
   ,@c_showecomfield,@c_Trackingno,@c_Buyerpo        --(CS01)
   ) -- SOS# 111204 
   
   SELECT @c_PrevOrderKey = @c_OrderKey

   FETCH NEXT FROM pick_cur INTO @c_sku, @c_loc, @n_Qty, @n_uom3, @c_storerkey,
 @c_orderkey, @c_UOM, @c_logicalloc, @c_LOT
END

CLOSE pick_cur
DEALLOCATE pick_cur

WHILE @@TRANCOUNT > 0
         COMMIT TRAN
         
         
-- Begin SOS20748
IF EXISTS(SELECT 1 FROM STORERCONFIG (NOLOCK)
           WHERE Storerkey = @c_StorerKey AND 
                 Configkey = 'ULVITF_PCF_WHEN_GEN_PICKSLIP' AND 
                 SVALUE = '1')    -- New Config Key
BEGIN
   DECLARE
   @c_TableName        NVARCHAR(15),
   @c_OrderLineNumber  NVARCHAR(5),
   @c_TransmitLogKey   NVARCHAR(10)

   SELECT @c_OrderKey = ''
   WHILE ( @n_continue = 1 or @n_continue = 2 )
   BEGIN
      SELECT @c_OrderKey = MIN(OrderKey)
        FROM #temp_pick
       WHERE OrderKey > @c_OrderKey

      IF ISNULL(@c_OrderKey,'') = ''
         BREAK

      SELECT @c_StorerKey  = ORDERS.StorerKey,
             @c_TableName  = 
             CASE ORDERS.TYPE
                 WHEN 'WT' THEN 'ULVNSO'
                 WHEN 'W'  THEN 'ULVHOL'
                 WHEN 'WC' THEN 'ULVINVTRF'
                 WHEN 'WD' THEN 'ULVDAMWD'
                 ELSE 'ULVPCF'
              END
        FROM ORDERS (NOLOCK)
       WHERE ORDERS.OrderKey    = @c_OrderKey


      IF EXISTS(SELECT 1 FROM STORERCONFIG (NOLOCK)
                        WHERE Storerkey = @c_StorerKey AND 
                              Configkey = 'ULVITF' AND 
                              SVALUE = '1')
         AND EXISTS(SELECT 1 FROM STORERCONFIG (NOLOCK)
                        WHERE Storerkey = @c_StorerKey AND 
                              Configkey = 'ULVITF_PCF_WHEN_GEN_PICKSLIP' AND 
                              SVALUE = '1')    -- New Config Key
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM  STORERCONFIG (NOLOCK)
                                WHERE  StorerKey = @c_StorerKey AND 
                                       Configkey = 'ULVPODITF' AND 
                                       SValue = '1' )
         BEGIN
            SELECT @c_pickheaderkey = PickHeaderKey 
              FROM PickHeader (NOLOCK)
             WHERE WaveKey = @c_WaveKey
               AND Zone = '8'
               AND OrderKey = @c_OrderKey

            SELECT @c_OrderLineNumber = ''
            WHILE ( @n_continue = 1 or @n_continue = 2 )
            BEGIN
               SELECT @c_OrderLineNumber = MIN (Orderlinenumber)
                 FROM ORDERDETAIL (NOLOCK)
                WHERE Orderkey = @c_OrderKey
                  AND ORDERLINENUMBER > @c_OrderLineNumber

               IF ISNULL(@c_OrderLineNumber,'') = ''
                  BREAK

               IF NOT EXISTS (SELECT 1 FROM TRANSMITLOG2 (NOLOCK)
                               WHERE TableName = @c_TableName
                                 AND key1 = @c_OrderKey
                                 AND Key2 = @c_OrderLineNumber )
               BEGIN
                  SELECT @c_TransmitLogKey=''
                  SELECT @b_success=1

                  EXECUTE nspg_getkey
                  'TransmitLogKey2'
                  , 10
                  , @c_TransmitLogKey OUTPUT
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT
                  IF NOT @b_success=1
                  BEGIN
                     SELECT @n_continue=3
                  END

                  IF ( @n_continue = 1 or @n_continue = 2 )
                  BEGIN
                     BEGIN TRAN 
                     
                     INSERT TransmitLog2 (TransmitLogKey, Tablename, Key1, Key2, Key3, Transmitbatch)
                        VALUES (@c_TransmitLogKey, @c_TableName, @c_OrderKey, @c_OrderLineNumber, @c_Storerkey, @c_pickheaderkey )

                     SELECT @n_err= @@Error
                     IF NOT @n_err=0
                     BEGIN
                        SELECT @n_continue=3
                        Select @c_errmsg= CONVERT(char(250), @n_err), @n_err=22806
                        Select @c_errmsg= 'NSQL'+CONVERT(char(5), @n_err)+':Insert failed on TransmitLog2. (nsp_GetPickSlipWave)'+'('+'SQLSvr MESSAGE='+dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg))+')'
                        ROLLBACK TRAN 
                        GOTO QUIT 
                     END
                     ELSE
                     BEGIN
         COMMIT TRAN 
                     END 
                  END
               END
            END
         END
      END
   END
END -- if ULVITF_PCF_WHEN_GEN_PICKSLIP Turn on
-- End SOS20748

WHILE @@TRANCOUNT > 0
   COMMIT TRAN 
      
      
-- Start : SOS49892
SUCCESS:
   DECLARE @cOrdKey         NVARCHAR(10),
           @cStorerKey      NVARCHAR(15)
   
   DECLARE c_ord CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT Orderkey, Storerkey
      FROM  #TEMP_PICK
      ORDER BY Orderkey    

   OPEN c_ord  

   FETCH NEXT FROM c_ord INTO @cOrdKey, @cStorerKey
   WHILE @@FETCH_STATUS <> -1  
   BEGIN
      IF dbo.fnc_RTRIM(@cOrdKey) IS NULL OR dbo.fnc_RTRIM(@cOrdKey) = ''
          BREAK

      IF EXISTS(SELECT 1 FROM StorerConfig (NOLOCK) WHERE ConfigKey = 'ECCOHK_MANUALORD' And sValue = '1'
                AND StorerKey = @cStorerKey)
      BEGIN
         BEGIN TRAN
         EXEC dbo.ispGenTransmitLog 'NIKEHKMORD', @cOrdKey, '', @cStorerKey, ''  
               , @b_success OUTPUT
               , @n_err OUTPUT
               , @c_errmsg OUTPUT         

         IF @n_err <> 0   
         BEGIN  
            ROLLBACK TRAN  
            SELECT @n_continue=3
            SELECT @n_err = @@ERROR
            SELECT @c_errMsg = 'Insert into TransmitLog Failed (nsp_GetPickSlipWave)'                     
            GOTO QUIT 
         END  
         ELSE 
         BEGIN
            COMMIT TRAN 
         END
      END -- StorerConfig

      FETCH NEXT FROM c_ord INTO @cOrdKey, @cStorerKey
   END -- End while

   CLOSE c_ord
   DEALLOCATE c_ord
-- End : SOS49892
   
   SELECT * FROM #temp_pick Order By OrderKey, LogicalLocation -- SOS# 111204

   
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'nsp_GetPickSlipWave'  
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