SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_GetPickSlipWave_CBA                            */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Purposes                                       */
/* 17-Dec-2007  Ting     SOS93687 - Delivery Note for CIBA Vision       */
/*                       Taiwan  Copy from nsp_GetPickSlipWave          */
/* 28-Jan-2008  Shong    Fixing Bugs. Problem found when "No Space"     */
/*                       found in Address. Substring Function Failed    */
/* 02-03-2009   TLTING   With (ROWLOCK)                                 */
/* 07-Oct-2010  NJOW01   190651 - add column orders.adddate as time     */
/* 28-Jan-2019  TLTING_ext 1.1 enlarge externorderkey field length      */
/************************************************************************/
 
CREATE PROC [dbo].[nsp_GetPickSlipWave_CBA] (
@c_WaveKey          NVARCHAR(10) = '',
@c_OrderKeyStart    NVARCHAR(10) = '',
@c_OrderKeyEnd      NVARCHAR(10) = '',
@c_ExternOrderKeyStart     NVARCHAR(50) = '',   --tlting_ext
@c_ExternOrderKeyEnd       NVARCHAR(50) = ''
)
AS

BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
Declare @b_debug               NVARCHAR(1)

Set  @b_debug = 0 

DECLARE
@c_pickheaderkey    NVARCHAR(10),
@n_continue        int,
@c_errmsg          NVARCHAR(255),
@b_success            int,
@n_err             int,
@c_sku             NVARCHAR(20),
@n_qty             int,
@c_loc             NVARCHAR(10),
@n_cases           int,
@n_perpallet        int,
@c_orderkey           NVARCHAR(10),
@c_storer          NVARCHAR(15),
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
@c_Notes1           NVARCHAR(255),
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
@c_externorderkey   NVARCHAR(30),
@c_externpokey      NVARCHAR(20),
@c_invoiceno        NVARCHAR(10),
@d_deliverydate     datetime,
@c_rdd              NVARCHAR(10),
@c_putawayzone      NVARCHAR(10),
@c_zonedesc        NVARCHAR(60),
@c_busr8           NVARCHAR(30),        -- Added by YokeBeen on 21-May-2002 (FBR107)
@c_AltSku          NVARCHAR(20),        -- SOS57251
@c_Susr2           NVARCHAR(20),        -- SOS57251
@n_StartTCnt       int,
@c_ordertime       NVARCHAR(10) 

Declare @c_Addr4                NVARCHAR(45),
@c_Phone1               NVARCHAR(18),
@c_OrderType            NVARCHAR(255),
@c_PmtTerm        NVARCHAR(255),
@c_DeliveryPlace        NVARCHAR(30),
@c_IntermodalVehicle    NVARCHAR(30),
@c_wavekey_check        NVARCHAR(10)

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
   Addr4            NVARCHAR(45) NULL,
   Phone1           NVARCHAR(18) NULL,
   PostCode         NVARCHAR(15) NULL,
   Route            NVARCHAR(10) NULL,
   Route_Desc       NVARCHAR(60) NULL, -- RouteMaster.Desc
   TrfRoom          NVARCHAR(10) NULL,  -- wave.TrfRoom , Change by shong FBR7632
   Notes1           NVARCHAR(255) NULL,
   Notes2           NVARCHAR(60) NULL,
   IntermodalVehicle    NVARCHAR(30) NULL,
   PgGroup           int,
   RowNum            int,
   Carrierkey        NVARCHAR(60) NULL,
   VehicleNo         NVARCHAR(10) NULL,
   ExternOrderKey    NVARCHAR(30) NULL,
   ExternPOKey       NVARCHAR(20) NULL,
   DeliveryDate      datetime NULL,
   PendingFlag       NVARCHAR(10) NULL,
   Storerkey         NVARCHAR(15) NULL,
   StorerCompany     NVARCHAR(45) NULL,
   OrderType         NVARCHAR(255) NULL,
   PmtTerm           NVARCHAR(255) NULL,
   DeliveryPlace     NVARCHAR(30) NULL,
   OrderTime         NVARCHAR(10) NULL)

SELECT @n_continue = 1
SELECT @n_RowNo = 0
SELECT @c_firstorderkey = 'N'


IF @b_debug = '1'
BEGIN
   Select '@c_wavekey', @c_wavekey
   SELECT '@c_OrderKeyStart', @c_OrderKeyStart , '@c_OrderKeyEnd', @c_OrderKeyEnd
   SELECT '@c_ExternOrderKeyStart', @c_ExternOrderKeyStart, '@c_ExternOrderKeyEnd', @c_ExternOrderKeyEnd
END 

IF @b_debug = '1'
BEGIN
   SELECT ORDERS.storerkey, ORDERS.OrderKey, wavedetail.wavekey
   FROM   wavedetail (NOLOCK), ORDERS (NOLOCK)
   WHERE  ORDERS.Userdefine08 = 'Y' -- only for wave plan orders.
   AND    wavedetail.OrderKey = ORDERS.OrderKey
   AND   ( ISNULL(dbo.fnc_RTrim(@c_wavekey), '') = '' OR wavedetail.wavekey = @c_wavekey) 
   AND   ( wavedetail.OrderKey >= @c_OrderKeyStart AND wavedetail.OrderKey <= @c_OrderKeyEnd )
   AND   ( ORDERS.ExternOrderKey >= @c_ExternOrderKeyStart AND ORDERS.ExternOrderKey <= @c_ExternOrderKeyEnd )
   GROUP BY ORDERS.storerkey, ORDERS.OrderKey, wavedetail.wavekey
   ORDER BY ORDERS.ORDERKEY
END 

DECLARE pack_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT ORDERS.storerkey, ORDERS.OrderKey, wavedetail.wavekey
FROM   wavedetail (NOLOCK), ORDERS (NOLOCK)
WHERE  ORDERS.Userdefine08 = 'Y' -- only for wave plan orders.
AND    wavedetail.OrderKey = ORDERS.OrderKey
AND   ( ISNULL(dbo.fnc_RTrim(@c_wavekey), '') = '' OR wavedetail.wavekey = @c_wavekey) 
AND   ( wavedetail.OrderKey >= @c_OrderKeyStart AND wavedetail.OrderKey <= @c_OrderKeyEnd )
AND   ( ORDERS.ExternOrderKey >= @c_ExternOrderKeyStart AND ORDERS.ExternOrderKey <= @c_ExternOrderKeyEnd )
GROUP BY ORDERS.storerkey, ORDERS.OrderKey, wavedetail.wavekey, ORDERS.Consigneekey
ORDER BY wavedetail.wavekey, ORDERS.Consigneekey, ORDERS.ORDERKEY

OPEN pack_cur

SELECT @c_PrevOrderKey = ''
FETCH NEXT FROM pack_cur INTO @c_storerkey, @c_OrderKey, @c_wavekey_check

WHILE (@@FETCH_STATUS <> -1)
BEGIN --While

   IF @b_debug = '1'
   BEGIN
      Select '@c_storerkey', @c_storerkey 
      SELECT '@c_OrderKey', @c_OrderKey
      SELECT '@c_wavekey_check', @c_wavekey_check
   END   

   
   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 8 - By Order
   IF EXISTS(SELECT 1 FROM PickHeader (NOLOCK) WHERE Wavekey = @c_wavekey_check AND Zone = '8')
   BEGIN
      SELECT @c_firsttime = 'N'
      SELECT @c_PrintedFlag = 'Y'
   END
   ELSE
   BEGIN
      SELECT @c_firsttime = 'Y'
      SELECT @c_PrintedFlag = 'N'
   END -- Record Not Exists

   IF @b_debug = '1'
   BEGIN
      SELECT '@c_firsttime - ' + @c_firsttime 
      SELECT '@c_PrintedFlag - ' + @c_PrintedFlag 
   END   
     
   -- Uses PickType as a Printed Flag
   -- Added BY SHONG, Only update when PickHeader Exists
   IF @c_firsttime = 'N' 
   BEGIN
      BEGIN TRAN
   
      UPDATE PickHeader with (ROWLOCK)
      SET PickType = '1',
          TrafficCop = NULL
      WHERE WaveKey = @c_wavekey_check
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

--    IF @c_OrderKey <> @c_PrevOrderKey
--    BEGIN
      IF NOT EXISTS( SELECT 1 FROM PICKHEADER (NOLOCK) 
                     WHERE WaveKey = @c_wavekey_check 
                       AND OrderKey = @c_OrderKey AND ZONE = '8')
      BEGIN  --Not Exist in PickHeader
         EXECUTE nspg_GetKey
         'PICKSLIP',
         9,
            @c_pickheaderkey  OUTPUT,
         @b_success        OUTPUT,
         @n_err            OUTPUT,
         @c_errmsg         OUTPUT

         SELECT @c_pickheaderkey = 'P' + @c_pickheaderkey
      
         IF @b_debug = '1'
         BEGIN
            SELECT 'INSERT PICKHEADER ' + @c_pickheaderkey
         END

         BEGIN TRAN

         INSERT INTO PICKHEADER
         (PickHeaderKey,    OrderKey,    WaveKey, PickType, Zone, TrafficCop)
         VALUES
         (@c_pickheaderkey, @c_OrderKey, @c_wavekey_check,     '0',      '8',  '')
      
         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            ROLLBACK TRAN
            GOTO QUIT
         END
         ELSE
         BEGIN

            IF NOT Exists(SELECT 1 FROM PickingInfo (NOLOCK) WHERE PickSlipNo = @c_pickheaderkey)
            BEGIN
               INSERT INTO PickingInfo  (PickSlipNo, ScanInDate, PickerID, ScanOutDate)
               VALUES (@c_pickheaderkey, GetDate(), sUser_sName(), NULL)
               SELECT @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  ROLLBACK TRAN
                  GOTO QUIT
               END
            END      

            WHILE @@TRANCOUNT > 0 
               COMMIT TRAN
         END

         SELECT @c_firstorderkey = 'Y'
      END  --NOT EXIST in PICKHEADER
      ELSE
      BEGIN -- EXIST in PickHeader
         SELECT @c_pickheaderkey = PickHeaderKey 
         FROM  PickHeader (NOLOCK)
         WHERE WaveKey = @c_wavekey_check
         AND   Zone = '8'
         AND   OrderKey = @c_OrderKey
      END -- Exist in PickHeader
--   END  -- @c_OrderKey <> @c_PrevOrderKey
   IF dbo.fnc_RTrim(@c_OrderKey) = '' OR dbo.fnc_RTrim(@c_OrderKey) IS NULL
   BEGIN  --if @c_orderkey = ''
      SELECT @c_ConsigneeKey = '',
            @c_Company = '',
            @c_Addr1 = '',
            @c_Addr2 = '',
            @c_Addr3 = '',
            @c_Addr4 = '',
            @c_Phone1 = '',
            @c_PostCode = '',
            @c_Route = '',
            @c_Route_Desc = '',
            @c_Notes1 = '',
            @c_Notes2 = '',
            @c_OrderTime = ''
   END  --if @c_orderkey=''
   ELSE
   BEGIN --if @c_orderkey <> ''

      SELECT @c_ConsigneeKey = Substring(Orders.ConsigneeKey, 4, 11),
            @c_Company      = ORDERS.c_Company,
            @c_Addr1        =  CASE WHEN charindex(SPACE(2), ORDERS.C_Address1) > 0 THEN 
                               SubString(ORDERS.C_Address1, 1, charindex(SPACE(2), ORDERS.C_Address1) - 1) +
                                  dbo.fnc_LTrim(
                                    SUBSTRING(ORDERS.C_Address1, 
                                              charindex(SPACE(2), ORDERS.C_Address1), 
                                              LEN(ORDERS.C_Address1) - charindex(SPACE(2), ORDERS.C_Address1) + 1
                                              )
                                       )
                               ELSE ORDERS.C_Address1
                               END,
            @c_Addr2        = CASE WHEN charindex(SPACE(2), ORDERS.C_Address2) > 0 THEN 
                               SubString(ORDERS.C_Address2, 1, charindex(SPACE(2), ORDERS.C_Address2) - 1) +
                                dbo.fnc_LTrim(
                                    SUBSTRING(ORDERS.C_Address2, 
                                              charindex(SPACE(2), ORDERS.C_Address2), 
                                              LEN(ORDERS.C_Address2) - charindex(SPACE(2), ORDERS.C_Address2) + 1
                                              )
                                       )
                               ELSE ORDERS.C_Address2
                               END,
            @c_Addr3        = CASE WHEN charindex(SPACE(2), ORDERS.C_Address3) > 0 THEN 
                               SubString(ORDERS.C_Address3, 1, charindex(SPACE(2), ORDERS.C_Address3) - 1) +
                                  dbo.fnc_LTrim(
                                    SUBSTRING(ORDERS.C_Address3, 
                                              charindex(SPACE(2), ORDERS.C_Address3), 
                                              LEN(ORDERS.C_Address3) - charindex(SPACE(2), ORDERS.C_Address3) + 1
                                              )
                                       )
                               ELSE ORDERS.C_Address3
                               END,
            @c_Addr4        = CASE WHEN charindex(SPACE(2), ORDERS.C_Address4) > 0 THEN 
                               SubString(ORDERS.C_Address4, 1, charindex(SPACE(2), ORDERS.C_Address4) - 1) +
                                  dbo.fnc_LTrim(
                                    SUBSTRING(ORDERS.C_Address4, 
                                              charindex(SPACE(2), ORDERS.C_Address4), 
                                              LEN(ORDERS.C_Address4) - charindex(SPACE(2), ORDERS.C_Address4) + 1
                                              )
                                       )
                               ELSE ORDERS.C_Address4
                               END,
            @c_Phone1       = ORDERS.C_Phone1,
            @c_PostCode     = ORDERS.C_Zip,
            @c_Notes1       = CONVERT(NVARCHAR(255), ORDERS.Notes),
            @c_Notes2       = CONVERT(NVARCHAR(60), ORDERS.Notes2),
            @c_labelprice   = ISNULL( ORDERS.LabelPrice, 'N' ),
            @c_route        = ORDERS.Route,
            @c_externorderkey = dbo.fnc_RTrim(ORDERS.ExternOrderKey),
            @c_trfRoom    = ORDERS.Door,
            @c_externpokey  = ORDERS.ExternPoKey,
            @c_InvoiceNo    = ORDERS.InvoiceNo,
            @d_DeliveryDate = ORDERS.DeliveryDate,
            @c_rdd           = ORDERS.RDD,
            @c_IntermodalVehicle = Orders.IntermodalVehicle,
            @c_OrderType    = CT.Long,
            @c_PmtTerm      = CP.Long,
            @c_DeliveryPlace      = Orders.DeliveryPlace,
            @c_OrderTime    = SUBSTRING(CAST(ORDERS.AddDate AS CHAR),12,8) 
      FROM   ORDERS (NOLOCK)
            Left Join Codelkup CT (nolock) on ( CT.Code = Orders.Type AND CT.ListName = 'ORDERTYPE' )
            Left Join Codelkup CP (nolock) on ( CP.Code = Orders.PmtTerm AND CP.ListName = 'CBAPAYMENT' )
      WHERE  ORDERS.OrderKey = @c_OrderKey


   END -- IF @c_OrderKey <> ''

   SELECT @c_Route_Desc  = IsNull(RouteMaster.Descr, '')
   FROM   RouteMaster (NOLOCK)
   WHERE  Route = @c_Route

   SELECT @c_storercompany = Company          
   FROM  STORER (NOLOCK)
   WHERE STORERKEY = @c_storerkey

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
   IF @c_Addr4         IS NULL SELECT @c_Addr4 = ''
   IF @c_Phone1        IS NULL SELECT @c_Phone1 = ''
   IF @c_IntermodalVehicle IS NULL SELECT @c_IntermodalVehicle = ''
   IF @c_OrderType     IS NULL SELECT @c_OrderType = ''
   IF @c_PmtTerm       IS NULL SELECT @c_PmtTerm = ''
   IF @c_DeliveryPlace       IS NULL SELECT @c_DeliveryPlace = ''
   IF @c_OrderTime     IS NULL SELECT @c_OrderTime = ''
   
   SELECT @n_RowNo = @n_RowNo + 1

   IF @b_debug = '1'
   BEGIN
      SELECT 'INSERT #Temp_Pick '
   END

   INSERT INTO #Temp_Pick
   (PickSlipNo,          wavekey,          OrderKey,         ConsigneeKey,
   Company,             Addr1,            Addr2,            PgGroup,
   Addr3,          PostCode,         Route,           Route_Desc,
   Addr4,          Phone1, IntermodalVehicle,   OrderType,     
   PmtTerm,          DeliveryPlace,       
   TrfRoom,             Notes1,           RowNum,           Notes2,
   CarrierKey,       VehicleNo,        
   ExternOrderKey,   ExternPoKey,
   DeliveryDate,     PendingFlag,      Storerkey,  
   StorerCompany,    OrderTime)    
   VALUES
   (@c_pickheaderkey,      @c_wavekey_check,       @c_OrderKey,      @c_ConsigneeKey,
   @c_Company,          @c_Addr1,         @c_Addr2,         0,
   @c_Addr3,            @c_PostCode,      @c_Route,         @c_Route_Desc,
   @c_Addr4,            @c_Phone1,        @c_IntermodalVehicle,   @c_OrderType,     
   @c_PmtTerm,          @c_DeliveryPlace,    
   @c_TrfRoom,          @c_Notes1,        @n_RowNo,         @c_Notes2,
   @c_Carrierkey,    @c_VehicleNo,    
   @c_externorderkey, @c_ExternPoKey,
   @d_deliverydate,  @c_rdd,           @c_storerkey,  
   @c_storercompany, @c_OrderTime) 

   SELECT @c_PrevOrderKey = @c_OrderKey

   FETCH NEXT FROM pack_cur INTO  @c_storerkey,   @c_orderkey, @c_wavekey_check
END

CLOSE pack_cur
DEALLOCATE pack_cur

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

   IF @b_debug = '1'
   BEGIN
      SELECT 'Configkey - ULVITF_PCF_WHEN_GEN_PICKSLIP'
   END

   SELECT @c_OrderKey = ''
   WHILE ( @n_continue = 1 or @n_continue = 2 )
   BEGIN
      SELECT @c_OrderKey = MIN(OrderKey)
        FROM #temp_pick
       WHERE OrderKey > @c_OrderKey

      IF ISNULL(@c_OrderKey,'') = ''
         BREAK

      SELECT @c_wavekey_check = wavekey
        FROM #temp_pick
       WHERE OrderKey = @c_OrderKey

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
             WHERE WaveKey = @c_wavekey_check
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
                                       
                     IF @b_debug = '1'
                     BEGIN
                        SELECT 'INSERT TransmitLog2 '
                     END

                     INSERT TransmitLog2 (TransmitLogKey, Tablename, Key1, Key2, Key3, Transmitbatch)
                        VALUES (@c_TransmitLogKey, @c_TableName, @c_OrderKey, @c_OrderLineNumber, @c_Storerkey, @c_pickheaderkey )

                     SELECT @n_err= @@Error
                     IF NOT @n_err=0
                     BEGIN
                        SELECT @n_continue=3
                        Select @c_errmsg= CONVERT(char(250), @n_err), @n_err=22806
                        Select @c_errmsg= 'NSQL'+CONVERT(char(5), @n_err)+':Insert failed on TransmitLog2. (nsp_GetPickSlipWave_CBA)'+'('+'SQLSvr MESSAGE='+dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg))+')'
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
      IF dbo.fnc_RTrim(@cOrdKey) IS NULL OR dbo.fnc_RTrim(@cOrdKey) = ''
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
            SELECT @c_errMsg = 'Insert into TransmitLog Failed (nsp_GetPickSlipWave_CBA)'                     
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
   
   SELECT * FROM #temp_pick

   
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'nsp_GetPickSlipWave_CBA'  
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