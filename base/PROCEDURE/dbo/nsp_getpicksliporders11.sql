SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE PROC [dbo].[nsp_GetPickSlipOrders11] (@c_wavekey NVARCHAR(10)) 
 AS
 BEGIN
    /*********************************************************************/
    /* WANYT 18 April 2003 FBR10227 TBL Forward Pick Ticket              */
    /* ----------------------------------------------------              */
    /* Modified by YokeBeen on 30-Apr-2003 - Similar error as SOS#10923  */
    /* (YokeBeen01)                                                      */
    /* Modified by SHONG on 20th May 2003 - Added Loc Aisle for FPA loc  */
    /* Modified by YokeBeen on 05-Jun-2003 - SOS#11555 & SOS#11635       */
    /* (YokeBeen02)                                                      */
    /* Modified by YokeBeen on 04-Jul-2003 - SOS#12115 - (YokeBeen03)    */ 
    /* Modified by June on 27-Oct-2003 - SOS15520 Interface manual order */
    /* 21/11/03 1. Select RouteMaster.ZipCodeTo<>'EXP' only              */
    /*          2. Use same Transmitlog.Tablename as Nike (NIKEHKMORD)   */
    /* 03/12/03 SOS# 18060, Add Hold/Pack Flag                           */    
    /* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length  */
    /*********************************************************************/
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
    DECLARE    @c_pickheaderkey      NVARCHAR(10),
      @n_continue     int,
      @c_errmsg       NVARCHAR(255),
      @b_success      int,
      @n_err          int,
      @n_pickslips_required int
      
     CREATE TABLE #TEMP_PICK
        ( PickSlipNo      NVARCHAR(10) NULL,
--          LoadKey          NVARCHAR(10),
         OrderKey         NVARCHAR(10),
         ExternOrderkey   NVARCHAR(50),   --tlting_ext
         WaveKey          NVARCHAR(10),
         InvoiceNo        NVARCHAR(10),
         Route            NVARCHAR(10) NULL,
         TrfQuota         NVARCHAR(1) NULL, 
         PriceLabel       NVARCHAR(1) NULL,
         Company          NVARCHAR(45),
         Addr1            NVARCHAR(45) NULL,
         Addr2            NVARCHAR(45) NULL,
         Addr3            NVARCHAR(45) NULL,
         Addr4            NVARCHAR(45) NULL,
         Country          NVARCHAR(30) NULL,
         Notes1           NVARCHAR(60) NULL,
         Notes2           NVARCHAR(60) NULL,
         LOC              NVARCHAR(10) NULL, 
         Sku              NVARCHAR(20) NULL,
         SkuDesc          NVARCHAR(60) NULL,
         SkuMeasurement   NVARCHAR(10) NULL,
         Lottable02       NVARCHAR(18) NULL,
         Qty              int,
         DeliveryDate     NVARCHAR(25) NULL,
         Remark           NVARCHAR(25) NULL,
         Userdefine06     datetime,  -- Added By Vicky SOS#12654 25 July 2003
         UserDefine05     NVARCHAR(18) ) -- Added By SHONG SOS#18060 03-Dec-2003


       INSERT INTO #TEMP_PICK
       SELECT (SELECT PICKHEADER.PickHeaderKey FROM PICKHEADER (nolock)
               WHERE PICKHEADER.Wavekey = @c_wavekey
               AND PICKHEADER.OrderKey = ORDERS.OrderKey 
               AND PICKHEADER.ZONE = '8'),
--          @c_loadkey,
         ORDERS.Orderkey,
         ORDERS.ExternOrderkey,
         ISNULL(ORDERS.UserDefine09,''),
         ORDERS.Invoiceno,
         ORDERS.Route,
         CASE ORDERS.UserDefine04
               WHEN 'Tariff Quota' THEN 'Y'
               ELSE  'N'
                  END AS TrfQuota,
         CASE (SELECT 1 FROM ORDERDETAIL 
               WHERE ORDERDETAIL.Orderkey = ORDERS.Orderkey 
                 AND (ORDERDETAIL.UserDefine05 <> Null OR ORDERDETAIL.UserDefine05 = '' 
                  OR ORDERDETAIL.UserDefine05 > '0')  -- (YokeBeen02)
               GROUP BY ORDERDETAIL.ORDERKEY)      -- (YokeBeen01)
               WHEN 1 THEN 'Y'
               ELSE 'N'
                  END PriceLabel,   
         IsNull(ORDERS.C_Company, '') AS Company,  -- (YokeBeen02)
         IsNull(ORDERS.C_Address1, '')AS Addr1,    -- (YokeBeen02)   
         IsNull(ORDERS.C_Address2,'') AS Addr2,    -- (YokeBeen02)            
         IsNull(ORDERS.C_Address3,'') AS Addr3,    -- (YokeBeen02)
         IsNull(ORDERS.C_Address4,'') AS Addr4,    -- (YokeBeen02)   
         IsNull(ORDERS.C_Country,'')  AS Country,  -- (YokeBeen02)         
         CONVERT(NVARCHAR(60), IsNull(ORDERS.Notes,  '')) AS Notes1,
         CONVERT(NVARCHAR(60), IsNull(ORDERS.Notes2,  '')) AS Notes2,
         -- (YokeBeen03) - Start
--          CASE SKUxLOC.LocationType 
--                WHEN 'PICK' THEN PICKDETAIL.Loc
--                WHEN 'CASE' THEN PICKDETAIL.Loc
--                ELSE 'FPA ' + PickFaceList.LocAisle 
--                   END Loc,
         ISNULL(PickFaceList.Loc, 'FPA') AS Loc,
         -- (YokeBeen03) - End
         dbo.fnc_LTrim(dbo.fnc_RTrim(SUBSTRING(SKU.BUSR1,1,8))) + '-' +  
         dbo.fnc_LTrim(dbo.fnc_RTrim(SUBSTRING(SKU.BUSR1,9,3))) + '-' +
         dbo.fnc_LTrim(dbo.fnc_RTrim(SUBSTRING(SKU.BUSR1,12,3))) + '-' +
         dbo.fnc_LTrim(dbo.fnc_RTrim(SUBSTRING(SKU.BUSR1,15,1))) AS SKU,
         ISNULL(SKU.Descr,'') AS SkuDescr,
         ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(SUBSTRING(SKU.BUSR1,16,4))),'') AS SkuMeasurement,   
         LOTATTRIBUTE.Lottable02,
         SUM(PICKDETAIL.Qty) AS QTY,
         '_________________________' AS DeliveryDate,
         '_________________________' AS Remark,
         IsNull(ORDERS.Userdefine06,''), -- Added By Vicky SOS#12654 25 July 2003
         -- Added By Shong SOS#18060 03-Dec-2003 
         CASE When dbo.fnc_LTrim(dbo.fnc_RTrim(ORDERS.Userdefine05)) = 'PACK AND HOLD' Then 'Y'
              ELSE 'N'
         END 
   FROM PICKDETAIL (NOLOCK)
        JOIN ORDERS (NOLOCK) ON (PICKDETAIL.Orderkey = ORDERS.Orderkey AND ORDERS.UserDefine08 = 'Y')
        JOIN WAVEDETAIL (NOLOCK) ON (PICKDETAIL.Orderkey = WAVEDETAIL.Orderkey)   
        JOIN LOTATTRIBUTE (NOLOCK) ON (PICKDETAIL.Lot = LOTATTRIBUTE.Lot)  
        JOIN SKU (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey AND PICKDETAIL.Sku = SKU.Sku)
        JOIN SKUxLOC (NOLOCK) ON (PICKDETAIL.Loc = SKUxLOC.Loc AND PICKDETAIL.Storerkey = SKUxLOC.Storerkey 
                              AND PICKDETAIL.Sku = SKUxLOC.Sku)
        LEFT OUTER JOIN STORER (NOLOCK) ON (ORDERS.Consigneekey = STORER.Storerkey AND STORER.Type = '2')   
        -- (YokeBeen01) - Start
        LEFT OUTER JOIN (SELECT SKUxLOC.Storerkey, SKUxLOC.Sku, SKUxLOC.Loc, LOC.LocAisle FROM SKUxLOC (NOLOCK) 
                         JOIN LOC (NOLOCK) ON (SKUxLOC.Loc = LOC.Loc)
                         WHERE (SKUxLOC.LocationType = 'CASE' OR SKUxLOC.LocationType = 'PICK')) PickFaceList ON
        (SKU.Storerkey = PickFaceList.StorerKey AND SKU.Sku = PickFaceList.Sku)
        -- (YokeBeen01) - End
   WHERE PICKDETAIL.Status < '5'
     AND (PICKDETAIL.PickMethod = '8' OR PICKDETAIL.PickMethod = '')
     AND (WAVEDETAIL.Wavekey = @c_wavekey)
   GROUP BY ORDERS.Orderkey,
            ORDERS.ExternOrderkey,
            ISNULL(ORDERS.UserDefine09,''),
            ORDERS.Invoiceno,
            ORDERS.Route,
            ORDERS.UserDefine04,
            IsNull(ORDERS.C_Company, ''),    -- (YokeBeen02)
            IsNull(ORDERS.C_Address1, ''),   -- (YokeBeen02)   
            IsNull(ORDERS.C_Address2,''),    -- (YokeBeen02)            
            IsNull(ORDERS.C_Address3,''),    -- (YokeBeen02)
            IsNull(ORDERS.C_Address4,''),    -- (YokeBeen02)   
            IsNull(ORDERS.C_Country,'') ,    -- (YokeBeen02)         
            CONVERT(NVARCHAR(60), IsNull(ORDERS.Notes,  '')) ,
            CONVERT(NVARCHAR(60), IsNull(ORDERS.Notes2, '')) ,
            -- (YokeBeen03) - Start
--             SKUxLOC.Locationtype,
--             PICKDETAIL.Loc,
            ISNULL(PickFaceList.Loc, 'FPA'),
            -- (YokeBeen03) - End
            dbo.fnc_LTrim(dbo.fnc_RTrim(SUBSTRING(SKU.BUSR1,1,8))) + '-' +  
            dbo.fnc_LTrim(dbo.fnc_RTrim(SUBSTRING(SKU.BUSR1,9,3))) + '-' +
            dbo.fnc_LTrim(dbo.fnc_RTrim(SUBSTRING(SKU.BUSR1,12,3))) + '-' +
            dbo.fnc_LTrim(dbo.fnc_RTrim(SUBSTRING(SKU.BUSR1,15,1))) ,
            ISNULL(SKU.Descr,''),
            ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(SUBSTRING(SKU.BUSR1,16,4))),'') ,  
            LotAttribute.Lottable02,
            PickFaceList.LocAisle,
            IsNull(ORDERS.Userdefine06,''), -- Added By Vicky SOS#12654 25 July 2003 
            -- Added By Shong SOS#18060 03-Dec-2003 
            CASE When dbo.fnc_LTrim(dbo.fnc_RTrim(ORDERS.Userdefine05)) = 'PACK AND HOLD' Then 'Y'
                 ELSE 'N'
            END 

   
  BEGIN TRAN  
   -- Uses PickType as a Printed Flag  
   UPDATE PickHeader SET PickType = '1', TrafficCop = NULL 
   WHERE WaveKey = @c_waveKey 
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
      
      INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, Wavekey, PickType, Zone, TrafficCop)
      SELECT 'P' + RIGHT ( REPLICATE ('0', 9) + 
         dbo.fnc_LTrim( dbo.fnc_RTrim(
         STR( CAST(@c_pickheaderkey AS int) + ( select count(distinct orderkey) 
                                              from #TEMP_PICK as Rank 
                                              WHERE Rank.OrderKey < #TEMP_PICK.OrderKey ) 
             ) -- str
             )) -- dbo.fnc_RTrim
          , 9) 
          , OrderKey, Wavekey, '0', '8', ''
      FROM #TEMP_PICK WHERE PickSlipNo IS NULL
      GROUP By WaveKey, OrderKey

      UPDATE #TEMP_PICK 
      SET PickSlipNo = PICKHEADER.PickHeaderKey
      FROM PICKHEADER (NOLOCK)
      WHERE PICKHEADER.WaveKey = #TEMP_PICK.Wavekey
      AND   PICKHEADER.OrderKey = #TEMP_PICK.OrderKey
      AND   PICKHEADER.Zone = '8'
      AND   #TEMP_PICK.PickSlipNo IS NULL
   END
   GOTO SUCCESS

FAILURE:
     DELETE FROM #TEMP_PICK

SUCCESS:
   -- Start - Added By June on 27.Oct..2003
   -- SOS#15520 - TBLHK Interface Manual Order
   DECLARE @cOrdKey         NVARCHAR(10),
           @cStorerKey      NVARCHAR(15),
           @cZipCodeTo      NVARCHAR(15),            -- 21/11/03
           @cTransmitlogKey NVARCHAR(10)
   
   SELECT @cOrdKey = ''
   
   WHILE 1=1
   BEGIN
      SELECT @cOrdKey = MIN(OrderKey) 
      FROM #TEMP_PICK
      WHERE  OrderKey > @cOrdKey 

      IF dbo.fnc_RTrim(@cOrdKey) IS NULL OR dbo.fnc_RTrim(@cOrdKey) = ''
         BREAK

      SELECT @cStorerKey = STORERKEY
           , @cZipCodeTo = ZipCodeTo             -- 21/11/03
      FROM   ORDERS (NOLOCK) 
             LEFT OUTER JOIN ROUTEMASTER (NOLOCK) ON ORDERS.Route=ROUTEMASTER.Route         -- 21/11/03
      WHERE  OrderKey = @cOrdKey

      IF EXISTS(SELECT 1 FROM StorerConfig (NOLOCK) WHERE ConfigKey = 'TBLHK_MANUALORD' And sValue = '1'
                AND StorerKey = @cStorerKey)
         AND ISNULL(@cZipCodeTo,'')<>'EXP'       -- 21/11/03
      BEGIN
-- 21/11/03         IF NOT EXISTS (SELECT 1 FROM Transmitlog (NOLOCK) WHERE TableName = 'TBLHKMORD' AND Key1 = @cOrdKey)
         IF NOT EXISTS (SELECT 1 FROM Transmitlog (NOLOCK) WHERE TableName = 'NIKEHKMORD' AND Key1 = @cOrdKey)     -- 21/11/03
         BEGIN
            SELECT @cTransmitlogkey=''
            SELECT @b_success=1
            
            EXECUTE nspg_getkey
            'TransmitlogKey'
            ,10
            , @cTransmitlogKey OUTPUT
            , @b_success OUTPUT
            , @n_err OUTPUT
            , @c_errmsg OUTPUT
            IF NOT @b_success=1
            BEGIN
               SELECT @n_continue=3
               SELECT @n_err = @@ERROR
               SELECT @c_errMsg = 'Error Found When Generating TransmitLogKey (nsp_GetPickSlipOrders11)'
            END
            ELSE
            BEGIN
               INSERT TransmitLog (transmitlogkey,tablename,key1,key2, key3) 
-- 21/11/03               VALUES (@cTransmitlogKey, 'TBLHKMORD', @cOrdKey, '', '' )               
               VALUES (@cTransmitlogKey, 'NIKEHKMORD', @cOrdKey, '', @cStorerKey )               -- 21/11/03
               IF @@ERROR <> 0
               BEGIN
                  SELECT @n_continue=3
                  SELECT @n_err = @@ERROR
                  SELECT @c_errMsg = 'Insert into TransmitLog Failed (nsp_GetPickSlipOrders11)'
               END
            END
         END 
      END 
   END -- End while

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      execute nsp_logerror @n_err, @c_errmsg, 'nsp_GetPickSlipOrders11'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   -- End (SOS15520)
   
   SELECT * FROM #TEMP_PICK ORDER BY PickSlipNo, Loc, Sku  
   DROP Table #TEMP_PICK  
END


GO