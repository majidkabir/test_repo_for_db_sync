SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nsp_GetPickSlipWaveALL                            */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version:                                                        */
/*                                                                      */
/* Version:                                                             */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 15-Dec-2018  TLTING01  1.1 Missing nolock                            */
/* 28-Jan-2019  TLTING_ext 1.1 enlarge externorderkey field length      */
/************************************************************************/

-- Modification History
-- For Phase 3 Customisation..
-- Added new columns into Result Set
-- 1) BUSR8 (Poison Flag)
/* 15-Dec-2018  TLTING01  1.1 Missing nolock                          */
/* 28-Jan-2019  TLTING_ext 1.1 enlarge externorderkey field length      */

CREATE PROC [dbo].[nsp_GetPickSlipWaveALL] (@c_wavekey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
DECLARE
@c_pickheaderkey    NVARCHAR(10),
@n_continue  	    int,
@c_errmsg  	       NVARCHAR(255),
@b_success  	       int,
@n_err  	      	 int,
@c_sku  	      	 NVARCHAR(20),
@n_qty  	      	 int,
@c_loc  	      	 NVARCHAR(10),
@n_cases  	       int,
@n_perpallet        int,
@c_orderkey 	       NVARCHAR(10),
@c_storer  	       NVARCHAR(15),
@c_storercompany    NVARCHAR(45),
@c_ConsigneeKey     NVARCHAR(15),
@c_Company          NVARCHAR(45),
@c_Addr1            NVARCHAR(45),
@c_Addr2            NVARCHAR(45),
@c_Addr3            NVARCHAR(45),
@c_PostCode         NVARCHAR(15),
@c_Route            NVARCHAR(10),
@c_Route_Desc       NVARCHAR(60), -- RouteMaster.Desc
@c_TrfRoom          NVARCHAR(5),  -- wave.TrfRoom
@c_Notes1           NVARCHAR(60),
@c_Notes2           NVARCHAR(60),
@c_SkuDesc          NVARCHAR(60),
@n_CaseCnt          int,
@n_PalletCnt        int,
@n_InnerPack	       int,
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
@c_invoiceno	       NVARCHAR(10),
@d_deliverydate     datetime,
@c_rdd	      		 NVARCHAR(10),
@c_putawayzone      NVARCHAR(10),
@c_zonedesc	       NVARCHAR(60),
@c_busr8				 NVARCHAR(30)  		-- Added by YokeBeen on 21-May-2002 (FBR107)

DECLARE @c_PrevOrderKey     NVARCHAR(10),
@n_Pallets          int,
@n_Cartons          int,
@n_Eaches           int,
@n_UOMQty           int

CREATE TABLE #temp_pick
(  PickSlipNo     NVARCHAR(10),
   wavekey			 NVARCHAR(10),
   OrderKey         NVARCHAR(10),
   ConsigneeKey     NVARCHAR(15) NULL,
   Company          NVARCHAR(45) NULL,
   Addr1            NVARCHAR(45) NULL,
   Addr2            NVARCHAR(45) NULL,
   Addr3            NVARCHAR(45) NULL,
   PostCode         NVARCHAR(15) NULL,
   Route            NVARCHAR(10) NULL,
   Route_Desc       NVARCHAR(60) NULL, -- RouteMaster.Desc
   TrfRoom          NVARCHAR(5) NULL,  -- wave.TrfRoom
   Notes1           NVARCHAR(60) NULL,
   Notes2           NVARCHAR(60) NULL,
   LOC              NVARCHAR(10) NULL,
   SKU              NVARCHAR(20) NULL,
   SkuDesc          NVARCHAR(60) NULL,
   Qty              int,
   TempQty1   	   int,
   TempQty2   	   int,
   PrintedFlag      NVARCHAR(1),
   Zone             NVARCHAR(1),
   PgGroup          int,
   RowNum           int,
   Lot				 NVARCHAR(10),
   Carrierkey       NVARCHAR(60) NULL,
   VehicleNo        NVARCHAR(10) NULL,
   Lottable02       NVARCHAR(18) NULL,
   Lottable04       datetime NULL,
   LabelPrice   	   NVARCHAR(5) NULL,
	 ExternOrderKey   NVARCHAR(50) NULL,  --tlting_ext
   ExternPOKey	   NVARCHAR(20) NULL,
   InvoiceNo		 NVARCHAR(10) NULL,
   DeliveryDate	   datetime NULL,
   PendingFlag	   NVARCHAR(10) NULL,
   Storerkey		 NVARCHAR(15) NULL,
   StorerCompany    NVARCHAR(45) NULL,
   CaseCnt				int NULL,
   Putawayzone	 NVARCHAR(10) NULL,
   ZoneDesc         NVARCHAR(60) NULL,
   Innerpack        int NULL,
   Busr8			 NVARCHAR(30) NULL, -- Added by YokeBeen on 21-May-2002 (FBR107)
   Lottable03     NVARCHAR(18) NULL) -- Added by Shong 01-Jul-2002

SELECT @n_continue = 1
SELECT @n_RowNo = 0
SELECT @c_firstorderkey = 'N'

-- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 8 - By Order
IF EXISTS(SELECT 1 FROM PickHeader (NOLOCK)
WHERE Wavekey = @c_wavekey
AND   Zone = "8")
BEGIN
SELECT @c_firsttime = 'N'
SELECT @c_PrintedFlag = 'Y'
END
ELSE
BEGIN
SELECT @c_firsttime = 'Y'
SELECT @c_PrintedFlag = "N"
END -- Record Not Exists


BEGIN TRAN

-- Uses PickType as a Printed Flag
UPDATE PickHeader
SET PickType = '1',
TrafficCop = NULL
WHERE WaveKey = @c_wavekey
AND Zone = "8"
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


DECLARE pick_cur CURSOR  FAST_FORWARD READ_ONLY FOR
SELECT PickDetail.sku,       PickDetail.loc,
SUM(PickDetail.qty),  PACK.Qty,
PickDetail.storerkey, PickDetail.OrderKey,
PickDetail.UOM,       LOC.LogicalLocation,
Pickdetail.Lot
FROM   PickDetail (NOLOCK),  Wavedetail (NOLOCK),
PACK (NOLOCK),        LOC (NOLOCK)  , ORDERS (NOLOCK)
WHERE  PickDetail.OrderKey = Wavedetail.OrderKey
		AND 	 ORDERS.Orderkey = WaveDetail.Orderkey
		AND 	 ORDERS.Orderkey = PICKDETAIL.Orderkey
		AND 	 ORDERS.Userdefine08 = 'Y' -- only for wave plan orders.
--AND    PickDetail.Status < '5'
AND    PickDetail.Packkey = PACK.Packkey
AND    LOC.Loc = PICKDETAIL.Loc
AND    wavedetail.wavekey = @c_wavekey
AND    PICKDETAIL.Pickmethod = '8' -- user wants it to be on lists
GROUP BY PickDetail.sku,       PickDetail.loc,      PACK.Qty,
PickDetail.storerkey, PickDetail.OrderKey, PICKDETAIL.UOM,
LOC.LogicalLocation,  Pickdetail.Lot
ORDER BY PICKDETAIL.ORDERKEY

OPEN pick_cur

SELECT @c_PrevOrderKey = ""
FETCH NEXT FROM pick_cur INTO @c_sku, @c_loc, @n_Qty, @n_uom3, @c_storerkey,
@c_orderkey,  @c_UOM, @c_logicalloc, @c_lot

WHILE (@@FETCH_STATUS <> -1)
BEGIN --While
	IF @c_OrderKey <> @c_PrevOrderKey
	BEGIN
   --tlting01
	   IF NOT EXISTS( SELECT 1 FROM PICKHEADER  (NOLOCK) WHERE WaveKey = @c_wavekey AND OrderKey = @c_OrderKey AND ZONE = '8')
	   BEGIN  --Not Exist in PickHeader
	EXECUTE nspg_GetKey
	"PICKSLIP",
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
	(@c_pickheaderkey, @c_OrderKey, @c_wavekey,     "0",      "8",  "")

	SELECT @n_err = @@ERROR
	IF @n_err <> 0
	BEGIN
	   IF @@TRANCOUNT >= 1
	   BEGIN
	ROLLBACK TRAN
	   END
	END
	ELSE
	BEGIN
	   IF @@TRANCOUNT > 0
	COMMIT TRAN
	   ELSE
	ROLLBACK TRAN
	END
	SELECT @c_firstorderkey = 'Y'
	   END  --NOT EXIST in PICKHEADER
	   ELSE
BEGIN -- EXIST in PickHeader
	SELECT @c_pickheaderkey = PickHeaderKey FROM PickHeader (NOLOCK)
	WHERE WaveKey = @c_wavekey
	AND   Zone = "8"
	AND   OrderKey = @c_OrderKey
	   END -- Exist in PickHeader
	END  -- @c_OrderKey <> @c_PrevOrderKey
IF @c_OrderKey = ""
BEGIN  --if @c_orderkey = ""
SELECT @c_ConsigneeKey = "",
@c_Company = "",
@c_Addr1 = "",
@c_Addr2 = "",
@c_Addr3 = "",
@c_PostCode = "",
@c_Route = "",
@c_Route_Desc = "",
@c_Notes1 = "",
@c_Notes2 = ""
END  --if @c_orderkey=""
ELSE
BEGIN --if @c_orderkey <> ""
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
@c_externorderkey = dbo.fnc_RTrim(ExternOrderKey)+" ("+dbo.fnc_RTrim(type)+")" ,
						 @c_trfRoom 	  = ORDERS.Door,
						 @c_externpokey  = ORDERS.ExternPoKey,
						 @c_InvoiceNo    = ORDERS.InvoiceNo,
						 @d_DeliveryDate = ORDERS.DeliveryDate,
						 @c_rdd			  = ORDERS.RDD
FROM   ORDERS (NOLOCK)
WHERE  ORDERS.OrderKey = @c_OrderKey
END -- IF @c_OrderKey <> ""

/*
SELECT @c_TrfRoom   = IsNULL(wave.TrfRoom, ""),
@c_Route     = IsNULL(wave.Route, ""),
@c_VehicleNo = IsNULL(wave.TruckSize, ""),
@c_Carrierkey = IsNULL(wave.CarrierKey,"")
FROM   wave (NOLOCK)
WHERE  wavekey = @c_wavekey
*/

SELECT @c_Route_Desc  = IsNull(RouteMaster.Descr, "")
FROM   RouteMaster (NOLOCK)
WHERE  Route = @c_Route

SELECT @c_SkuDesc = IsNULL(Descr,""),
					 @c_busr8 = IsNULL(Busr8, '')
FROM   SKU  (NOLOCK)
WHERE  SKU = @c_SKU

SELECT @c_Lottable02 = Lottable02,
@d_Lottable04 = Lottable04,
@c_Lottable03 = Lottable03
FROM   LOTATTRIBUTE (NOLOCK)
WHERE  LOT = @c_LOT

SELECT @c_storercompany = Company
FROM	STORER (NOLOCK)
WHERE STORERKEY = @c_storerkey

SELECT @c_putawayzone = LOC.Putawayzone,
@c_zonedesc = PUTAWAYZONE.Descr
FROM LOC (nolock), PUTAWAYZONE (nolock)
WHERE 	PUTAWAYZONE.PUTAWAYZONE = LOC.PUTAWAYZONE and
LOC.LOC = @c_loc

IF @c_Lottable02    IS NULL SELECT @c_Lottable02 = ""
IF @d_Lottable04    IS NULL SELECT @d_Lottable04 = "01/01/1900"
IF @c_Notes1        IS NULL SELECT @c_Notes1 = ""
IF @c_Notes2        IS NULL SELECT @c_Notes2 = ""
IF @c_ConsigneeKey  IS NULL SELECT @c_ConsigneeKey = ""
IF @c_Company       IS NULL SELECT @c_Company = ""
IF @c_Addr1         IS NULL SELECT @c_Addr1 = ""
IF @c_Addr2         IS NULL SELECT @c_Addr2 = ""
IF @c_Addr3         IS NULL SELECT @c_Addr3 = ""
IF @c_PostCode      IS NULL SELECT @c_PostCode = ""
IF @c_Route         IS NULL SELECT @c_Route = ""
IF @c_CarrierKey    IS NULL SELECT @c_Carrierkey = ""
IF @c_Route_Desc    IS NULL SELECT @c_Route_Desc = ""

IF @c_superorderflag = "Y" SELECT @c_orderkey = ""

SELECT @n_RowNo = @n_RowNo + 1
SELECT @n_Pallets = 0,
@n_Cartons = 0,
@n_Eaches  = 0

SELECT @n_UOMQty = 0
SELECT @n_UOMQty = CASE @c_UOM
WHEN "1" THEN PACK.Pallet
WHEN "2" THEN PACK.CaseCnt
WHEN "3" THEN PACK.InnerPack
ELSE 1
END,
@n_CaseCnt = CaseCnt,
@n_InnerPack = Pack.InnerPack
FROM   PACK (NOLOCK), SKU (NOLOCK)
WHERE  SKU.SKU = @c_SKU
AND    PACK.PackKey = SKU.PackKey

INSERT INTO #Temp_Pick
(PickSlipNo,          wavekey,          OrderKey,         ConsigneeKey,
Company,             Addr1,            Addr2,            PgGroup,
Addr3,               PostCode,         Route, 				Route_Desc,
TrfRoom,          	Notes1,           RowNum,  			Notes2,
LOC,              	SKU,					SkuDesc, 			Qty,
TempQty1,  				TempQty2,     	   PrintedFlag,      Zone,
Lot,		    			CarrierKey,       VehicleNo,        Lottable02,
Lottable04, 	    	LabelPrice,       ExternOrderKey,	ExternPoKey,
InvoiceNo,	    		DeliveryDate,     PendingFlag, 		Storerkey,	
StorerCompany,    	CaseCnt,				Putawayzone, 		ZoneDesc,	
InnerPack,			 	Busr8,            Lottable03 )
VALUES
(@c_pickheaderkey,   	@c_wavekey,       @c_OrderKey,		@c_ConsigneeKey,
@c_Company,         	@c_Addr1,         @c_Addr2,			0,
@c_Addr3,           	@c_PostCode,      @c_Route,  			@c_Route_Desc,
@c_TrfRoom,       	@c_Notes1,			@n_RowNo,  			@c_Notes2,
@c_LOC,           	@c_SKU,  			@c_SKUDesc,       @n_Qty,
CAST(@c_UOM as int), @n_UOMQty,	   	@c_PrintedFlag,   "8",
@c_Lot,		   		@c_Carrierkey,    @c_VehicleNo,     @c_Lottable02,
@d_Lottable04, 	   @c_labelprice,    @c_externorderkey, @c_ExternPoKey,
@c_invoiceno,	   	@d_deliverydate,  @c_rdd, 				@c_storerkey,	
@c_storercompany, 	@n_CaseCnt,			@c_putawayzone, 	@c_ZoneDesc,	
@n_innerpack,			@c_busr8,         @c_Lottable03 )

SELECT @c_PrevOrderKey = @c_OrderKey
FETCH NEXT FROM pick_cur INTO @c_sku, @c_loc, @n_Qty, @n_uom3, @c_storerkey,
@c_orderkey, @c_UOM, @c_logicalloc, @c_LOT
END
CLOSE pick_cur
DEALLOCATE pick_cur
SELECT * FROM #temp_pick
TRUNCATE Table #temp_pick
END


GO