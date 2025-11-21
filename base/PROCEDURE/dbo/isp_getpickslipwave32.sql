SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_GetPickSlipWave32                              */
/* Creation Date:01-JUL-2021                                            */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By: PB- r_dw_print_wave_pickslip_32                           */
/*            copy from r_dw_print_wave_pickslip06                      */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 07-OCT-2021  CSCHONG       Devops scripts combine                   */
/************************************************************************/

CREATE PROC [dbo].[isp_GetPickSlipWave32] (
@c_wavekey          NVARCHAR(10))
AS

BEGIN
SET NOCOUNT ON 
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
@c_Addr4            NVARCHAR(45),
@c_PostCode         NVARCHAR(15),
@c_Route            NVARCHAR(10),
@c_Route_Desc       NVARCHAR(60), 
@c_TrfRoom          NVARCHAR(10),  
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
@c_externorderkey   NVARCHAR(45),
@c_externpokey      NVARCHAR(20),
@c_invoiceno        NVARCHAR(10),
@d_deliverydate     datetime,
@c_rdd              NVARCHAR(10),
@c_putawayzone      NVARCHAR(10),
@c_zonedesc         NVARCHAR(60),
@c_busr8            NVARCHAR(30),       
@c_AltSku           NVARCHAR(20),       
@c_Susr2            NVARCHAR(20),       
@n_StartTCnt        int,
@c_Id               NVARCHAR(18), 
@c_CountSku         NVARCHAR(10)
SET @n_StartTCnt=@@TRANCOUNT

DECLARE @c_PrevOrderKey       NVARCHAR(10),
        @n_Pallets            int,
        @n_Cartons            int,
        @n_Eaches             int,
        @n_UOMQty             int,
        @c_ServiceMode        NVARCHAR(30),                                                          
        @c_IntermodalVehicle  NVARCHAR(30)                                                           

SET @c_ServiceMode       = ''                                                                       
SET @c_IntermodalVehicle = ''                                                                       
   
CREATE TABLE #temp_pick (
   PickSlipNo        NVARCHAR(10),
   wavekey           NVARCHAR(10),
   OrderKey          NVARCHAR(10),
   ConsigneeKey      NVARCHAR(15) NULL,
   Company           NVARCHAR(45) NULL,
   Addr1             NVARCHAR(45) NULL,
   Addr2             NVARCHAR(45) NULL,
   Addr3             NVARCHAR(45) NULL,
   Addr4             NVARCHAR(45) NULL,
   PostCode          NVARCHAR(15) NULL,
   Route             NVARCHAR(10) NULL,
   Route_Desc        NVARCHAR(60) NULL, 
   TrfRoom           NVARCHAR(10) NULL, 
   Notes1            NVARCHAR(60) NULL,
   Notes2            NVARCHAR(60) NULL,
   LOC               NVARCHAR(10) NULL,
   SKU               NVARCHAR(20) NULL,
   SkuDesc           NVARCHAR(60) NULL,
   Qty               int,
   TempQty1          int,
   TempQty2          int,
   PrintedFlag       NVARCHAR(1),
   Zone              NVARCHAR(1),
   PgGroup           int,
   RowNum            int,
   Lot               NVARCHAR(10),
   Carrierkey        NVARCHAR(60) NULL,
   VehicleNo         NVARCHAR(10) NULL,
   Lottable02        NVARCHAR(18) NULL,
   Lottable04        datetime NULL,
   LabelPrice        NVARCHAR(5) NULL,
   ExternOrderKey    NVARCHAR(45) NULL,
   ExternPOKey       NVARCHAR(20) NULL,
   InvoiceNo         NVARCHAR(10) NULL,
   DeliveryDate      datetime NULL,
   PendingFlag       NVARCHAR(10) NULL,
   Storerkey         NVARCHAR(15) NULL,
   StorerCompany     NVARCHAR(45) NULL,
   CaseCnt           int NULL,
   Putawayzone       NVARCHAR(10) NULL,
   ZoneDesc          NVARCHAR(60) NULL,
   Innerpack         int NULL,
   Busr8             NVARCHAR(30) NULL, 
   Lottable03        NVARCHAR(18) NULL, 
   AltSKU            NVARCHAR(20) NULL, 
   SUSR2             NVARCHAR(20) NULL, 
   LogicalLocation   NVARCHAR(18) NULL, 
   ID                NVARCHAR(18) NULL,
   CountSku          NVARCHAR(10) NULL,
   InterModalVehicle NVARCHAR(30) NULL,                                                                    
   ServiceMode       NVARCHAR(30) NULL)      
                                                                 
SELECT @n_continue = 1
SELECT @n_RowNo = 0
SELECT @c_firstorderkey = 'N'

-- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 8 - By Order
IF EXISTS(SELECT 1 FROM PickHeader WITH (NOLOCK) WHERE Wavekey = @c_wavekey AND Zone = '8')
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
       Pickdetail.ID
FROM   PickDetail WITH (NOLOCK),  Wavedetail WITH (NOLOCK),
PACK WITH (NOLOCK), LOC WITH (NOLOCK), ORDERS WITH (NOLOCK)
WHERE  PickDetail.OrderKey = Wavedetail.OrderKey
AND    ORDERS.Orderkey = WaveDetail.Orderkey
AND    ORDERS.Orderkey = PICKDETAIL.Orderkey
AND    ORDERS.Userdefine08 = 'Y' -- only for wave plan orders.
AND    PickDetail.Status < '5'
AND    PickDetail.Packkey = PACK.Packkey
AND    LOC.Loc = PICKDETAIL.Loc
AND    wavedetail.wavekey = @c_wavekey
AND    ( PICKDETAIL.Pickmethod = '8' OR PICKDETAIL.Pickmethod = ' ' )-- user wants it to be on lists

GROUP BY PickDetail.sku,  PickDetail.loc, PickDetail.ID, PACK.Qty,
PickDetail.storerkey, PickDetail.OrderKey 
ORDER BY PickDetail.loc, PickDetail.ID,PickDetail.sku

OPEN pick_cur

SELECT @c_PrevOrderKey = ''
FETCH NEXT FROM pick_cur INTO @c_sku, @c_loc, @n_Qty, @n_uom3, @c_storerkey,
@c_orderkey,  @c_Id

WHILE (@@FETCH_STATUS <> -1)
BEGIN --While
   IF @c_OrderKey <> @c_PrevOrderKey
   BEGIN
      IF NOT EXISTS( SELECT 1 FROM PICKHEADER WITH (NOLOCK) WHERE WaveKey = @c_wavekey AND OrderKey = @c_OrderKey AND ZONE = '8')
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
         FROM  PickHeader WITH (NOLOCK)
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
            @c_Notes2 = ''
   END  --if @c_orderkey=''
   ELSE
   BEGIN --if @c_orderkey <> ''
      SELECT @c_ConsigneeKey = Orders.Consigneekey,
            @c_Company      = ORDERS.c_Company,
            @c_Addr1        = ORDERS.C_Address1,
            @c_Addr2        = ORDERS.C_Address2,
            @c_Addr3        = ORDERS.C_Address3,
            @c_Addr4        = ORDERS.C_Address4,
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
            @c_rdd           = ORDERS.RDD
           ,@c_IntermodalVehicle = ISNULL(RTRIM(ORDERS.IntermodalVehicle),'')                       
      FROM   ORDERS WITH (NOLOCK)
      WHERE  ORDERS.OrderKey = @c_OrderKey
   END -- IF @c_OrderKey <> ''
  

    BEGIN TRAN

     UPDATE PICKDETAIL WITH (ROWLOCK)        
     SET  PickSlipNo = @c_pickheaderkey       
         ,EditWho = SUSER_NAME()      
         ,EditDate= GETDATE()       
         ,TrafficCop = NULL       
     FROM ORDERS     OH WITH (NOLOCK)      
     JOIN PICKDETAIL PD ON (OH.Orderkey = PD.Orderkey)   
     WHERE PD.OrderKey = @c_OrderKey    
     AND   ISNULL(PickSlipNo,'') = ''   

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
     
   SELECT @c_Route_Desc  = IsNull(RouteMaster.Descr, '')
   FROM   RouteMaster WITH (NOLOCK)
   WHERE  Route = @c_Route

   SELECT @c_SkuDesc = IsNULL(Descr,''),
          @c_busr8 = IsNULL(Busr8, '')
   FROM   SKU  WITH (NOLOCK)
   WHERE  STorerKey = @c_StorerKey
   AND    SKU = @c_SKU

   SELECT @c_storercompany = Company          
   FROM  STORER WITH (NOLOCK)
   WHERE STORERKEY = @c_storerkey

   SELECT @c_putawayzone = LOC.Putawayzone,
          @c_zonedesc = PUTAWAYZONE.Descr
   FROM   LOC WITH (nolock), PUTAWAYZONE WITH (nolock)
   WHERE  PUTAWAYZONE.PUTAWAYZONE = LOC.PUTAWAYZONE 
   AND    LOC.LOC = @c_loc


   SET @c_ServiceMode       = ''  
   SELECT @c_ServiceMode = ISNULL(CONVERT(NVARCHAR(30), CL.Notes),'')
   FROM CODELKUP CL WITH (NOLOCK) 
   WHERE CL.ListName = 'TRANSMETH'
   AND   CL.Code = @c_IntermodalVehicle


   IF @c_Lottable02    IS NULL SELECT @c_Lottable02 = ''
   IF @d_Lottable04    IS NULL SELECT @d_Lottable04 = '01/01/1900'
   IF @c_Notes1        IS NULL SELECT @c_Notes1 = ''
   IF @c_Notes2        IS NULL SELECT @c_Notes2 = ''
   IF @c_ConsigneeKey  IS NULL SELECT @c_ConsigneeKey = ''
   IF @c_Company       IS NULL SELECT @c_Company = ''
   IF @c_Addr1         IS NULL SELECT @c_Addr1 = ''
   IF @c_Addr2         IS NULL SELECT @c_Addr2 = ''
   IF @c_Addr3         IS NULL SELECT @c_Addr3 = ''
   IF @c_Addr4         IS NULL SELECT @c_Addr4 = ''
   IF @c_PostCode      IS NULL SELECT @c_PostCode = ''
   IF @c_Route         IS NULL SELECT @c_Route = ''
   IF @c_CarrierKey    IS NULL SELECT @c_Carrierkey = ''
   IF @c_Route_Desc    IS NULL SELECT @c_Route_Desc = ''
   IF @c_superorderflag = 'Y' SELECT @c_orderkey = ''

   INSERT INTO #Temp_Pick
   (PickSlipNo,         wavekey,          OrderKey,         ConsigneeKey,
   Company,             Addr1,            Addr2,            PgGroup,
   Addr3,               Addr4,            PostCode,         Route,            Route_Desc,
   TrfRoom,             Notes1,           RowNum,           Notes2,
   LOC,                 SKU,              SkuDesc,          Qty,
   TempQty1,            TempQty2,         PrintedFlag,      Zone,
   Lot,                 CarrierKey,       VehicleNo,        Lottable02,
   Lottable04,          LabelPrice,       ExternOrderKey,   ExternPoKey,
   InvoiceNo,           DeliveryDate,     PendingFlag,      Storerkey,  
   StorerCompany,       CaseCnt,          Putawayzone,      ZoneDesc,   
   InnerPack,           Busr8,            Lottable03,
   AltSKU,              SUSR2,
   /*LogicalLocation,*/ID
  , InterModalVehicle, ServiceMode)                                                                  
   VALUES
   (@c_pickheaderkey,   @c_wavekey,       @c_OrderKey,      @c_ConsigneeKey,
   @c_Company,          @c_Addr1,         @c_Addr2,         0,
   @c_Addr3,            @c_Addr4,         @c_PostCode,      @c_Route,         @c_Route_Desc,
   @c_TrfRoom,          @c_Notes1,        @n_RowNo,         @c_Notes2,
   @c_LOC,              @c_SKU,           @c_SKUDesc,       @n_Qty,
   '',                  '',               @c_PrintedFlag,   '8',
   '',                  @c_Carrierkey,    @c_VehicleNo,     @c_Lottable02,
   @d_Lottable04,       @c_labelprice,    @c_externorderkey, @c_ExternPoKey,
   @c_invoiceno,        @d_deliverydate,  @c_rdd,           @c_storerkey,  
   @c_storercompany,    @n_CaseCnt,       @c_putawayzone,   @c_ZoneDesc,   
   @n_innerpack,        @c_busr8,         @c_Lottable03,
   @c_AltSKU,           @c_Susr2,
   @c_Id
  ,@c_InterModalVehicle, @c_ServiceMode)                                                            

   SELECT @c_CountSku = Count(distinct(Sku)) FROM #Temp_Pick WITH (NOLOCK)
   WHERE PickSlipNo = @c_pickheaderkey
   AND ZoneDesc = @c_ZoneDesc
   GROUP BY PickSlipNo 

   UPDATE #Temp_Pick WITH (ROWLOCK)
   SET CountSku = @c_CountSku
   WHERE PickSlipNo = @c_pickheaderkey
   AND ZoneDesc = @c_ZoneDesc
   
   SELECT @c_PrevOrderKey = @c_OrderKey

   FETCH NEXT FROM pick_cur INTO @c_sku, @c_loc, @n_Qty, @n_uom3, @c_storerkey,
                                 @c_orderkey, @c_Id
END

CLOSE pick_cur
DEALLOCATE pick_cur

WHILE @@TRANCOUNT > 0
         COMMIT TRAN
         
        
IF EXISTS(SELECT 1 FROM STORERCONFIG WITH (NOLOCK)
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
        FROM ORDERS WITH (NOLOCK)
       WHERE ORDERS.OrderKey    = @c_OrderKey


      IF EXISTS(SELECT 1 FROM STORERCONFIG WITH (NOLOCK)
                WHERE Storerkey = @c_StorerKey AND 
                      Configkey = 'ULVITF' AND 
                      SVALUE = '1')
         AND EXISTS(SELECT 1 FROM STORERCONFIG WITH (NOLOCK)
                    WHERE Storerkey = @c_StorerKey AND 
                    Configkey = 'ULVITF_PCF_WHEN_GEN_PICKSLIP' AND 
                    SVALUE = '1')    -- New Config Key
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM  STORERCONFIG WITH (NOLOCK)
                                WHERE  StorerKey = @c_StorerKey AND 
                                       Configkey = 'ULVPODITF' AND 
                                       SValue = '1' )
         BEGIN
            SELECT @c_pickheaderkey = PickHeaderKey 
            FROM PickHeader WITH (NOLOCK)
            WHERE WaveKey = @c_WaveKey
            AND Zone = '8'
            AND OrderKey = @c_OrderKey

            SELECT @c_OrderLineNumber = ''
            WHILE ( @n_continue = 1 or @n_continue = 2 )
            BEGIN
               SELECT @c_OrderLineNumber = MIN (Orderlinenumber)
               FROM ORDERDETAIL WITH (NOLOCK)
               WHERE Orderkey = @c_OrderKey
               AND ORDERLINENUMBER > @c_OrderLineNumber

               IF ISNULL(@c_OrderLineNumber,'') = ''
                  BREAK

               IF NOT EXISTS (SELECT 1 FROM TRANSMITLOG2 WITH (NOLOCK)
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
                        Select @c_errmsg= 'NSQL'+CONVERT(char(5), @n_err)+':Insert failed on TransmitLog2. (isp_GetPickSlipWave32)'+'('+'SQLSvr MESSAGE='+dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg))+')'
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


WHILE @@TRANCOUNT > 0
   COMMIT TRAN 
      
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

      IF EXISTS(SELECT 1 FROM StorerConfig WITH (NOLOCK) WHERE ConfigKey = 'ECCOHK_MANUALORD' And sValue = '1'
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
            SELECT @c_errMsg = 'Insert into TransmitLog Failed (isp_GetPickSlipWave32)'                     
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

   
-- SELECT * FROM #temp_pick Order By OrderKey, LogicalLocation  
   SELECT   pickslipno,wavekey,orderkey,consigneekey,addr1,addr2,addr3, --SOS#129583
            addr4,loc,sku,skudesc,sum(qty) as qty,externorderkey,storerkey,zonedesc,id,countsku, putawayzone
          , ServiceMode                                                                             
   FROM #temp_pick
   group by pickslipno,orderkey,wavekey,storerkey,consigneekey,addr1,addr2,addr3,
            addr4,externorderkey,zonedesc,loc,id,sku,skudesc , qty,countsku ,putawayzone
          , InterModalVehicle
          , ServiceMode
   --Order By OrderKey 
   Order By InterModalVehicle
          , ConsigneeKey 
          , OrderKey
          , Loc
          , ID
          , Sku 
            
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_GetPickSlipWave32'  
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