SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nsp_GetPickSlipWave_08                             */
/* Creation Date: 01-Apr-2009                                           */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: SOS#133187 - SSL HK - Descrete Picking Slip                 */
/*          - Printed together with Move Ticket & Pickslip in a         */
/*            composite report                                          */
/*          - copy from nsp_GetPickSlipWave_FPA                         */
/*                                                                      */
/* Called By: RCM - Popup Pickslip in Loadplan / WavePlan               */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 29-May-2009  NJOW01  1.1   SOS#137437 - Add ID column                */
/* 01-Sep-2009  Leong   1.2   SOS#145352 - Update EditDate & EditWho    */
/* 15-Oct-2009  NJOW02  1.3   SOS#150111-  Pickslip showing unexpected  */
/*                                         values sum the qty column.   */
/* 25-Feb-2010  ChewKP  1.4   SOS#161525 - Add BuyerPO (ChewKP01)       */
/* 14-Mar-2012  NJOW03  1.5   243992-Show billtokey or consigneeky depend*/
/*                            on storerconfig WAVEPS08_SHOWCONSIGNEE    */
/* 28-Jan-2019  TLTING_ext 1.6 enlarge externorderkey field length      */
/************************************************************************/

CREATE PROC [dbo].[nsp_GetPickSlipWave_08] (
@c_wavekey_type          NVARCHAR(13)
)
AS

BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
DECLARE
@c_pickheaderkey    NVARCHAR(10),
@n_continue    	  int,
@c_errmsg  	        NVARCHAR(255),
@b_success  	     int,
@n_err  	      	  int,
@c_sku  	      	  NVARCHAR(20),
@n_qty  	      	  int,
@c_loc  	      	  NVARCHAR(10),
@n_cases  	        int,
@n_perpallet        int,
@c_orderkey 	     NVARCHAR(10),
@c_storer  	        NVARCHAR(15),
@c_storercompany    NVARCHAR(45),
@c_ConsigneeKey     NVARCHAR(15),
@c_Company          NVARCHAR(45),
@c_Addr1            NVARCHAR(45),
@c_Addr2            NVARCHAR(45),
@c_Addr3            NVARCHAR(45),
@c_PostCode         NVARCHAR(15),
@c_Route            NVARCHAR(10),
@c_Route_Desc       NVARCHAR(60), -- RouteMaster.Desc
@c_TrfRoom          NVARCHAR(10),
@c_Notes1           NVARCHAR(120),
@c_Notes2           NVARCHAR(120),
@c_SkuDesc          NVARCHAR(60),
@n_CaseCnt          int,
@n_PalletCnt        int,
@n_InnerPack	     int,
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
@c_invoiceno	     NVARCHAR(10),
@d_deliverydate     datetime,
@c_rdd	      	  NVARCHAR(10),
@c_putawayzone      NVARCHAR(10),
@c_zonedesc	        NVARCHAR(60),
@c_busr8				  NVARCHAR(30),
@c_AltSku			  NVARCHAR(20),
@c_Susr2				  NVARCHAR(20),
@c_BUSR10           NVARCHAR(30),
@n_StartTCnt        int ,
@c_Lottable01       NVARCHAR(18),
@n_StdCube          Float,
@n_StdGrossWgt      Float, 
@c_PackUOM1         NVARCHAR(10), 
@c_PackUOM2         NVARCHAR(10), 
@c_PackUOM3         NVARCHAR(10),
@c_ID              NVARCHAR(18),  --NJOW01
@c_BuyerPO         NVARCHAR(20) -- ChewKP01

SET @n_StartTCnt=@@TRANCOUNT

DECLARE @c_PrevOrderKey     NVARCHAR(10),
@n_Pallets          int,
@n_Cartons          int,
@n_Eaches           int,
@n_UOMQty           int

DECLARE @c_toloc            NVARCHAR(10),
        @c_moveid           NVARCHAR(18),
        @c_wavekey          NVARCHAR(10),
        @c_Type             NVARCHAR(2),
        @c_ToLocPutawayzone NVARCHAR(10)

CREATE TABLE #temp_pick (
   PickSlipNo       NVARCHAR(10),
   wavekey			  NVARCHAR(10),
   OrderKey         NVARCHAR(10),
   ConsigneeKey     NVARCHAR(15) NULL,
   Company          NVARCHAR(45) NULL,
   Addr1            NVARCHAR(45) NULL,
   Addr2            NVARCHAR(45) NULL,
   Addr3            NVARCHAR(45) NULL,
   PostCode         NVARCHAR(15) NULL,
   Route            NVARCHAR(10) NULL,
   Route_Desc       NVARCHAR(60) NULL, -- RouteMaster.Desc
   TrfRoom          NVARCHAR(10) NULL,  -- wave.TrfRoom
   Notes1           NVARCHAR(120) NULL,
   Notes2           NVARCHAR(120) NULL,
   LOC              NVARCHAR(10) NULL,
   SKU              NVARCHAR(20) NULL,
   SkuDesc          NVARCHAR(60) NULL,
   Qty              int,
   TempQty1   	     int,
   TempQty2   	     int,
   PrintedFlag      NVARCHAR(1),
   Zone             NVARCHAR(1),
   PgGroup          int,
   RowNum           int,
   Lot				  NVARCHAR(10),
   Carrierkey       NVARCHAR(60) NULL,
   VehicleNo        NVARCHAR(10) NULL,
   Lottable02       NVARCHAR(18) NULL,
   Lottable04       datetime NULL,
   LabelPrice   	  NVARCHAR(5) NULL,
   ExternOrderKey   NVARCHAR(50) NULL,   --tlting_ext
   ExternPOKey	     NVARCHAR(20) NULL,
   InvoiceNo		  NVARCHAR(10) NULL,
   DeliveryDate	  datetime NULL,
   PendingFlag	     NVARCHAR(10) NULL,
   Storerkey		  NVARCHAR(15) NULL,
   StorerCompany    NVARCHAR(45) NULL,
   CaseCnt			  int NULL,
   Putawayzone		  NVARCHAR(10) NULL,
   ZoneDesc         NVARCHAR(60) NULL,
   Innerpack        int NULL,
   Busr8				  NVARCHAR(30) NULL, 
   Lottable03       NVARCHAR(18) NULL, 
	AltSKU			  NVARCHAR(20) NULL,	
	SUSR2				  NVARCHAR(20) NULL,
   BUSR10           NVARCHAR(30) NULL,
   ToLoc            NVARCHAR(10) NULL,
   MoveId           NVARCHAR(18) NULL,
   ToLocPutawayzone NVARCHAR(10) NULL,
   Lottable01       NVARCHAR(18) NULL,   
   StdCube          Float NULL,
   StdGrossWgt      Float NULL, 
   PackUOM1         NVARCHAR(10) NULL, 
   PackUOM2         NVARCHAR(10) NULL, 
   PackUOM3         NVARCHAR(10) NULL,
   ID               NVARCHAR(18) NULL,	--NJOW01
   BuyerPO          NVARCHAR(20) NULL)  --ChewKP01

SELECT @n_continue = 1
SELECT @n_RowNo = 0
SELECT @c_firstorderkey = 'N'

SELECT @c_wavekey = LEFT(@c_wavekey_type, 10)
SELECT @c_Type = RIGHT(@c_wavekey_type,2)

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
-- Only update when PickHeader Exists
IF @c_firsttime = 'N' 
BEGIN
   BEGIN TRAN

   UPDATE PickHeader
   SET PickType = '1',
       EditDate=GETDATE(), EditWho=Suser_Sname(), --SOS#145352
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
       Pickdetail.Lot,       ISNULL(Pickdetail.ToLoc, ''),
       ISNULL(Pickdetail.DropID, ''),
       PICKDETAIL.ID  --NJOW01
FROM   PickDetail (NOLOCK),  Wavedetail (NOLOCK),
PACK (NOLOCK), LOC (NOLOCK), ORDERS (NOLOCK)
WHERE  PickDetail.OrderKey = Wavedetail.OrderKey
AND 	 ORDERS.Orderkey = WaveDetail.Orderkey
AND 	 ORDERS.Orderkey = PICKDETAIL.Orderkey
AND 	 ORDERS.Userdefine08 = 'Y' -- only for wave plan orders.
AND    PickDetail.Status < '5'
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
LOC.LogicalLocation,  Pickdetail.Lot, Pickdetail.ToLoc, Pickdetail.DropID,
Pickdetail.ID --NJOW01
ORDER BY PICKDETAIL.ORDERKEY

OPEN pick_cur

SELECT @c_PrevOrderKey = ''
FETCH NEXT FROM pick_cur INTO @c_sku, @c_loc, @n_Qty, @n_uom3, @c_storerkey,
@c_orderkey,  @c_UOM, @c_logicalloc, @c_lot, @c_toloc, @c_moveid, @c_Id --NJOW01

WHILE (@@FETCH_STATUS <> -1)
BEGIN --While
	IF @c_OrderKey <> @c_PrevOrderKey
	BEGIN
	   IF NOT EXISTS( SELECT 1 FROM PICKHEADER (NOLOCK) WHERE WaveKey = @c_wavekey AND OrderKey = @c_OrderKey AND ZONE = '8')
	   BEGIN  --Not Exist in PickHeader
         EXECUTE nspg_GetKey
         'PICKSLIP',
         9,
         	@c_pickheaderkey	OUTPUT,
         @b_success     	OUTPUT,
         @n_err         	OUTPUT,
         @c_errmsg      	OUTPUT

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
   IF RTrim(@c_OrderKey) = '' OR RTrim(@c_OrderKey) IS NULL
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
      SELECT @c_ConsigneeKey = CASE WHEN ISNULL(SC.Svalue,'') =  '1' THEN    --NJOW02
                                 Orders.Consigneekey               
                               ELSE 
                                 Orders.BillToKey
                               END,
            @c_Company      = ORDERS.c_Company,
            @c_Addr1        = ORDERS.C_Address1,
            @c_Addr2        = ORDERS.C_Address2,
            @c_Addr3        = ORDERS.C_Address3,
            @c_PostCode     = ORDERS.C_Zip,
            @c_Notes1       = CONVERT(NVARCHAR(120), ORDERS.Notes),
            @c_Notes2       = CONVERT(NVARCHAR(120), ORDERS.Notes2),
            @c_labelprice   = ISNULL( ORDERS.LabelPrice, 'N' ),
            @c_route        = ORDERS.Route,
            @c_externorderkey = RTrim(ORDERS.ExternOrderKey)+' ('+RTrim(ORDERS.type)+')' ,
            @c_trfRoom 	  = ORDERS.Door,
            @c_externpokey  = ORDERS.ExternPoKey,
            @c_InvoiceNo    = ORDERS.InvoiceNo,
            @d_DeliveryDate = ORDERS.DeliveryDate,
            @c_rdd			  = ORDERS.RDD,
            @c_BuyerPO      = ORDERS.BuyerPO -- (ChewKP01)            
      FROM   ORDERS (NOLOCK)
      LEFT JOIN   STORERCONFIG SC (NOLOCK) ON (ORDERS.Storerkey = SC.Storerkey AND SC.Configkey='WAVEPS08_SHOWCONSIGNEE')  --NJOW02
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
   		 @c_busr8 = IsNULL(Busr8, ''),
          @c_BUSR10 = IsNULL(BUSR10,''),
          @n_StdCube = IsNULL(StdCube,0.0),
          @n_StdGrossWgt = IsNULL(StdGrossWgt,0.0)
   FROM   SKU  (NOLOCK)
   WHERE  STorerKey = @c_StorerKey
   AND    SKU = @c_SKU

   SELECT @c_Lottable01 = Lottable01,
          @c_Lottable02 = Lottable02,
		    @c_Lottable03 = Lottable03,          
	       @d_Lottable04 = Lottable04
   FROM   LOTATTRIBUTE (NOLOCK)
   WHERE  LOT = @c_LOT

   SELECT @c_storercompany = Company			 
   FROM	STORER (NOLOCK)
   WHERE STORERKEY = @c_storerkey

   SELECT @c_putawayzone = LOC.Putawayzone,
          @c_zonedesc = PUTAWAYZONE.Descr
   FROM   LOC (nolock), PUTAWAYZONE (nolock)
   WHERE  PUTAWAYZONE.PUTAWAYZONE = LOC.PUTAWAYZONE 
   AND    LOC.LOC = @c_loc

   SELECT @c_ToLocPutawayzone = ''

   IF @c_toloc <> '' AND @c_toloc IS NOT NULL
   BEGIN
	   SELECT @c_ToLocPutawayzone = LOC.Putawayzone,
	          @c_zonedesc = PUTAWAYZONE.Descr
	   FROM   LOC (nolock), PUTAWAYZONE (nolock)
	   WHERE  PUTAWAYZONE.PUTAWAYZONE = LOC.PUTAWAYZONE 
	   AND    LOC.LOC = @c_toloc
   END

   IF @c_Lottable01    IS NULL SELECT @c_Lottable01 = ''
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
   FROM	STORER (NOLOCK)
   WHERE STORERKEY = @c_ConsigneeKey   
   
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
         @n_InnerPack = Pack.InnerPack,
			@c_AltSku = AltSKU   -- SOS57251
         ,@c_PackUOM1 = PACKUOM1        
         ,@c_PackUOM2 = PACKUOM2
         ,@c_PackUOM3 = PACKUOM3
   FROM   PACK (NOLOCK), SKU (NOLOCK)
   WHERE  SKU.StorerKey = @c_StorerKey
   AND    SKU.SKU = @c_SKU
   AND    PACK.PackKey = SKU.PackKey

   INSERT INTO #Temp_Pick
   (PickSlipNo,         wavekey,          OrderKey,         ConsigneeKey,
   Company,             Addr1,            Addr2,            PgGroup,
   Addr3,               PostCode,         Route, 				Route_Desc,
   TrfRoom,          	Notes1,           RowNum,  			Notes2,
   LOC,              	SKU,					SkuDesc, 			Qty,
   TempQty1,  				TempQty2,     	   PrintedFlag,      Zone,
   Lot,		    			CarrierKey,       VehicleNo,        Lottable02,
   Lottable04, 	    	LabelPrice,       ExternOrderKey,	ExternPoKey,
   InvoiceNo,	    		DeliveryDate,     PendingFlag, 		Storerkey,	
   StorerCompany,    	CaseCnt,				Putawayzone, 		ZoneDesc,	
   InnerPack,			 	Busr8,            Lottable03,       AltSKU,
	SUSR2,               BUSR10,           ToLoc,            MoveId,
   ToLocPutawayzone,    Lottable01,       StdCube,          StdGrossWgt, 
   PackUOM1,            PackUOM2,         PackUOM3,         ID, --NJOW01
   BuyerPO)  -- (ChewKP01)
   VALUES
   (@c_pickheaderkey,   @c_wavekey,       @c_OrderKey,		@c_ConsigneeKey,
   RTrim(@c_Company),  	RTrim(@c_Addr1),  RTrim(@c_Addr2),  0,
   RTrim(@c_Addr3),    	@c_PostCode,      @c_Route,  			@c_Route_Desc,
   @c_TrfRoom,       	RTrim(@c_Notes1),	@n_RowNo,  			RTrim(@c_Notes2),
   @c_LOC,           	@c_SKU,  			@c_SKUDesc,       @n_Qty,
   CAST(@c_UOM as int), @n_UOMQty,	   	@c_PrintedFlag,   '8',
   @c_Lot,		   		@c_Carrierkey,    @c_VehicleNo,     @c_Lottable02,
   @d_Lottable04, 	   @c_labelprice,    RTrim(@c_externorderkey), @c_ExternPoKey,
   @c_invoiceno,	   	@d_deliverydate,  @c_rdd, 				@c_storerkey,	
   @c_storercompany, 	@n_CaseCnt,			@c_putawayzone, 	RTrim(@c_ZoneDesc),	
   @n_innerpack,			@c_busr8,         @c_Lottable03,    @c_AltSKU,
	@c_Susr2,            @c_BUSR10,        @c_toloc,         @c_moveid,
   ISNULL(@c_ToLocPutawayzone, ''),       @c_Lottable01,    @n_StdCube,   @n_StdGrossWgt, 
   @c_PackUOM1,         @c_PackUOM2,      @c_PackUOM3 ,     @c_Id,   --NJOW01
   @c_BuyerPO) -- (ChewKP01)

   SELECT @c_PrevOrderKey = @c_OrderKey

   FETCH NEXT FROM pick_cur INTO @c_sku, @c_loc, @n_Qty, @n_uom3, @c_storerkey,
   @c_orderkey, @c_UOM, @c_logicalloc, @c_LOT, @c_toloc, @c_moveid, @c_Id --NJOW01
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
                        Select @c_errmsg= 'NSQL'+CONVERT(char(5), @n_err)+':Insert failed on TransmitLog2. (nsp_GetPickSlipWave_08)'+'('+'SQLSvr MESSAGE='+LTrim(RTrim(@c_errmsg))+')'
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
      IF RTrim(@cOrdKey) IS NULL OR RTrim(@cOrdKey) = ''
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
            SELECT @c_errMsg = 'Insert into TransmitLog Failed (nsp_GetPickSlipWave_08)'                     
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
	
	/*SELECT TP.* 
   FROM #temp_pick TP */
   
    --NJOW02
   SELECT PickSlipNo, wavekey, OrderKey, ConsigneeKey, Company, Addr1, Addr2, Addr3, PostCode, Route, Route_Desc, TrfRoom,      
   Notes1, Notes2, LOC, SKU, SkuDesc, SUM(Qty) AS Qty, 0 AS TempQty1, 0 AS TempQty2, PrintedFlag, Zone, PgGroup, 0 AS RowNum, '' AS Lot, Carrierkey,    
   VehicleNo, Lottable02, Lottable04, LabelPrice, ExternOrderKey, ExternPOKey, InvoiceNo, DeliveryDate, PendingFlag,	  
   Storerkey, StorerCompany, CaseCnt, Putawayzone, ZoneDesc, Innerpack, Busr8, Lottable03, AltSKU, SUSR2, BUSR10,         
   ToLoc, MoveId, ToLocPutawayzone, Lottable01, StdCube, StdGrossWgt, PackUOM1, PackUOM2, PackUOM3,ID ,BuyerPO
   FROM #TEMP_PICK
   GROUP BY PickSlipNo, wavekey, OrderKey, ConsigneeKey, Company, Addr1, Addr2, Addr3, PostCode, Route, Route_Desc, TrfRoom,      
   Notes1, Notes2, LOC, SKU, SkuDesc, PrintedFlag, Zone, PgGroup, Carrierkey,    
   VehicleNo, Lottable02, Lottable04, LabelPrice, ExternOrderKey, ExternPOKey, InvoiceNo, DeliveryDate, PendingFlag,	  
   Storerkey, StorerCompany, CaseCnt, Putawayzone, ZoneDesc, Innerpack, Busr8, Lottable03, AltSKU, SUSR2, BUSR10,         
   ToLoc, MoveId, ToLocPutawayzone, Lottable01, StdCube, StdGrossWgt, PackUOM1, PackUOM2, PackUOM3,ID ,BuyerPO  

   	
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'nsp_GetPickSlipWave_08'  
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