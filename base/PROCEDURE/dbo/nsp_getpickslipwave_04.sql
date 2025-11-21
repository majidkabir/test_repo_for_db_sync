SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  nsp_GetPickSlipWave_04                             */
/* Creation Date: 02-Jun-2005                                           */
/* Copyright: IDS                                                       */
/* Written by: MaryVong                                                 */
/*                                                                      */
/* Purpose: Create Pickslip for IDSTW-Loreal from Wave Plan (SOS34356)  */
/*                                                                      */
/* Input Parameters:  @c_wavekye  - Wavekey                             */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_print_wave_pickslip_04             */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.9                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   ver. Purposes                                   */
/* 2006-08-14  ONG01         Do not filter PICKDETAIL.PickMethod = '8'  */
/* 2006-09-29  ONG02         Add Lottable02, DeliveryNote               */
/* 2006-11-03  ONG03         Show Summary Group by SKU                  */
/* 2006-11-15  ONG04        Add Delivery Date                           */
/* 2006-11-28  YokeBeen      Added ConfigKey check for AutoScanIn.      */
/*                           - (SOS#63265) (YokeBeen01)                 */
/* 2006-11-28  ONG05        SOS63291 Add OrderGroup                     */
/* 2009-03-02  TLTING        UPDATE PICKHEADER WITH (ROWLOCK)           */
/* 2010-02-24  NJOW01   1.2  162002 - If the sku.susr4 = 'SSCC'         */
/*                           print '**Scan Serial No**' on the line     */
/*                           below the SKU field                        */
/* 2010-04-06  CHEWKP   1.3  SOS#167061 Sort by Loc.LogicalLoc(ChewKP01)*/
/* 2010-12-27  NJOW01   1.4  199662-Add Lottable03                      */
/* 2011-12-28  YTWan    1.5  SOS#231293- Add Label Flag.(Wan01)         */
/* 2012-10-12  NJOW02   1.6  258416-Add C_City                          */
/* 2012-10-19  NJOW03   1.7  259309-Add RetailSKU                       */
/* 2013-06-17  NJOW04   1.8  279821-Use skugroup to indicate sku        */
/*                           internal consumption                       */
/* 2013-07-10  Leong    1.9  SOS# 283436 - Prevent Pickslip number not  */
/*                                         tally with nCounter table.   */
/* 2014-05-14  NJOW05 	2.0  310894-Add scan flag and sku barcode flag  */
/* 2014-09-12  NJOW06   2.1  320541-config map sku.notes1 as descr      */
/* 2016-04-04  CSCHONG  2.2  365709-config to group by lottable (CS01)  */
/* 2016-04-21  CSCHONG  2.3  365709-bugs fix to sum up by casecnt(CS02) */
/* 2016-04-29  CSCHONG  2.4  368606-Add new field (CS03)                */
/* 2017-02-21  CSCHONG  2.5  WMS-1093 - add new field (CS04)            */
/* 2017-03-30  CSCHONG  2.6  WMS-1468 add new field (CS05)              */
/* 2018-01-26  CSCHONG  2.7  WMS-3873 New field with report config(CS06)*/
/* 28-Jan-2019  TLTING_ext 2.8 enlarge externorderkey field length      */
/************************************************************************/

CREATE PROC [dbo].[nsp_GetPickSlipWave_04] (@c_wavekey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE  @n_continue             INT,
            @c_errmsg               NVARCHAR(255),
            @b_success              INT,
            @n_err                  INT,
            @n_starttcnt            INT,
            @n_pickslips_required   INT,
            @c_PickHeaderKey        NVARCHAR(10),
            @c_FirstTime            NVARCHAR(1),
            @c_PrintedFlag          NVARCHAR(1),
            @c_Orderkey             NVARCHAR(10),      -- ONG03
            @c_SKUGROUP             NVARCHAR(10),      -- ONG03
            @n_Qty                  INT,               -- ONG03
            @c_StorerKey            NVARCHAR(15),      -- (YokeBeen01)
            @c_PickSlipNo           NVARCHAR(10),      -- (YokeBeen01)
            @c_VASLBLValue          NVARCHAR(10),      -- (Wan01)
				@c_pickgrp              NVARCHAR(1),       --(CCS01)
				@c_getUdf01             NVARCHAR(100),     --(CS03)
				@c_getUdf02             NVARCHAR(100),     --(CS03)
				@c_ordudf05             NVARCHAR(20),      --(CS03)
				@c_udf01                NVARCHAR(5),       --(CS03)                                               
				@c_getorderkey          NVARCHAR(10),      --(CS03)
				@c_condition            NVARCHAR(100),     --(CS03)
				@c_ExecStatements       NVARCHAR(4000),    --(CS03)  
				@c_ExecAllStatements    NVARCHAR(4000),    --(CS03) 
				@c_ExecArguments        NVARCHAR(4000)     --(CS03) 
				,@c_CSKUUDF04           NVARCHAR(30)       --(CS06)
           
           
   SET @c_udf01 = ''        

   SELECT @n_starttcnt=@@TRANCOUNT, @n_continue=1, @b_success=0, @n_err=0, @c_errmsg=''

   CREATE TABLE #TEMP_PICK
      ( PickSlipNo      NVARCHAR(10) NULL,
      OrderKey          NVARCHAR(10),
      ExternOrderkey    NVARCHAR(50),   --tlting_ext
      WaveKey           NVARCHAR(10),
      StorerKey         NVARCHAR(15),
      InvoiceNo         NVARCHAR(10),
      Route             NVARCHAR(10) NULL,
      RouteDescr        NVARCHAR(60) NULL,
      ConsigneeKey      NVARCHAR(15) NULL,
      C_Company         NVARCHAR(45) NULL,
      C_Addr1           NVARCHAR(45) NULL,
      C_Addr2           NVARCHAR(45) NULL,
      C_Addr3           NVARCHAR(45) NULL,
      C_PostCode        NVARCHAR(18) NULL,
      C_City            NVARCHAR(45) NULL,
      Sku               NVARCHAR(20) NULL,
      SkuDescr          NVARCHAR(60) NULL,
      Lot               NVARCHAR(10),
      Lottable01        NVARCHAR(18) NULL, -- Batch No
      Lottable04        datetime NULL, -- Expiry Date
      Qty               INT,           -- PickDetail.Qty
      Loc               NVARCHAR(10) NULL,
      MasterUnit        INT,
      LowestUOM         NVARCHAR(10),
      CaseCnt           INT,
      InnerPack         INT,
      Capacity          float,
      GrossWeight       float,
      PrintedFlag       NVARCHAR(1),
      Notes1            NVARCHAR(60) NULL,
      Notes2            NVARCHAR(60) NULL,
      Lottable02        NVARCHAR(18) NULL,    -- ONG02
      DeliveryNote      NVARCHAR(20) NULL,    -- ONG02
      SKUGROUP          NVARCHAR(10) NULL,    -- ONG03
      SkuGroupQty       INT,              -- ONG03
      DeliveryDate      datetime NULL,    -- ONG04
      OrderGroup        NVARCHAR(20) NULL,    -- ONG05
      scanserial        NVARCHAR(30) NULL,    -- NJOW01
      LogicalLoc        NVARCHAR(18) NULL,    -- ChewKP01
      Lottable03        NVARCHAR(18) NULL,    -- NJOW01
      LabelFlag         NVARCHAR(10) NULL, -- YTWan
      RetailSku         NVARCHAR(20) NULL,
      Internalflag      NVARCHAR(10) NULL, -- NJOW04
      scancaseidflag    NVARCHAR(20) NULL, --NJOW05
      showbarcodeflag   NCHAR(1) NULL, --NJOW05
      UDF01             NVARCHAR(5) NULL,  --CS03
      OHUDF04           NVARCHAR(20) NULL, --CS04
      showfield         NCHAR(1) NULL, --CS05
      ODUDF05           NVARCHAR(5) NULL, --CS05
      showbuyerpo       NCHAR(1) NULL, --CS06
      CSKUUDF04         NVARCHAR(30) NULL ) --CS06
   -- Check if wavekey existed
   IF EXISTS(SELECT 1 FROM PICKHEADER (NOLOCK)
               WHERE WaveKey = @c_wavekey
               AND   Zone = '8')
   BEGIN
      SELECT @c_FirstTime = 'N'
      SELECT @c_PrintedFlag = 'Y'
   END
   ELSE
   BEGIN
      SELECT @c_FirstTime = 'Y'
      SELECT @c_PrintedFlag = 'N'
   END

   BEGIN TRAN
   -- Uses PickType as a Printed Flag
   UPDATE PICKHEADER WITH (ROWLOCK)  -- tlting
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
         GOTO FAILURE
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
         GOTO FAILURE
      END
   END

   --(Wan01) - START
   SELECT TOP 1 @c_Storerkey = ORDERS.Storerkey
   FROM PICKHEADER WITH (NOLOCK)
   JOIN ORDERS WITH (NOLOCK) ON (PICKHEADER.OrderKey = ORDERS.OrderKey)
   WHERE PICKHEADER.Wavekey = @c_wavekey
   AND PICKHEADER.ZONE = '8'

   SELECT @c_VASLBLValue = SValue
   FROM STORERCONFIG WITH (NOLOCK)
   WHERE Storerkey = @c_Storerkey
   AND   Configkey = 'WAVEPICKSLIP04_VASLBL'
   --(Wan01) - END

	--(CCS01) -  Start
	SELECT @c_pickgrp = CASE WHEN ISNULL(Code,'') <> '' THEN 'Y' ELSE 'N' END
	FROM CODELKUP  WITH (NOLOCK)
	WHERE Code = 'PICKPGRP' 
   AND Listname = 'REPORTCFG' 
	AND Long = 'r_dw_print_wave_pickslip_04'
	AND ISNULL(Short,'') <> 'N'
	AND Storerkey = @c_Storerkey

	--(CCS01) -  End

   BEGIN TRAN

   -- Select all records into temp table
   INSERT INTO #TEMP_PICK
   SELECT (SELECT PICKHEADER.PickHeaderKey FROM PICKHEADER (NOLOCK)
            WHERE PICKHEADER.Wavekey = @c_wavekey
            AND PICKHEADER.OrderKey = ORDERS.OrderKey
            AND PICKHEADER.ZONE = '8'),
   ORDERS.Orderkey,
   ORDERS.ExternOrderkey,
   WAVEDETAIL.WaveKey,
   ISNULL(ORDERS.StorerKey, ''),
   ISNULL(ORDERS.Invoiceno, ''),
   ISNULL(ORDERS.Route, ''),
   ISNULL(ROUTEMASTER.Descr, ''),
   ISNULL(dbo.fnc_RTrim(ORDERS.ConsigneeKey), ''),
   ISNULL(dbo.fnc_RTrim(ORDERS.C_Company), ''),
   ISNULL(dbo.fnc_RTrim(ORDERS.C_Address1), ''),
   ISNULL(dbo.fnc_RTrim(ORDERS.C_Address2), ''),
   ISNULL(dbo.fnc_RTrim(ORDERS.C_Address3), ''),
   ISNULL(dbo.fnc_RTrim(ORDERS.C_Zip), ''),
   ISNULL(dbo.fnc_RTrim(ORDERS.C_City), ''),
   SKU.Sku,
   --ISNULL(SKU.Descr,'') AS SkuDescr,
 	 CASE WHEN ISNULL(CL4.Code,'') <> '' AND ISNULL(SKU.Notes1,'') <> '' THEN SKU.Notes1 ELSE ISNULL(SKU.Descr,'') END AS SkuDescr, --NJOW06   
   --PICKDETAIL.Lot,                     --(CCS01)
	CASE WHEN @c_pickgrp <> 'Y' THEN PICKDETAIL.Lot ELSE '' END as Lot, --(CCS01)
   ISNULL(LOTATTRIBUTE.Lottable01, ''),
   ISNULL(CONVERT(NVARCHAR(10), LOTATTRIBUTE.Lottable04,112), '01/01/1900'),
   SUM(PICKDETAIL.Qty) AS QTY,
   ISNULL(PICKDETAIL.Loc, ''),
   ISNULL(PACK.Qty, 0) AS MasterUnit,
   ISNULL(PACK.PackUOM3, '') AS LowestUOM,
   ISNULL(PACK.CaseCnt, 0),
   ISNULL(PACK.InnerPack, 0),
   ISNULL(ORDERS.Capacity, 0.00),
   ISNULL(ORDERS.GrossWeight, 0.00),
   @c_PrintedFlag,
   CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes, '')) AS Notes1,
   CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes2, '')) AS Notes2,
   ISNULL(LOTATTRIBUTE.Lottable02, '') Lottable02,          -- ONG02
   CASE WHEN ISNULL(CL6.Code,'') = '' OR ISNULL(CL6.Code,'') = 'N' THEN ISNULL(Orders.DeliveryNote,'') 
    ELSE ISNULL(orders.buyerpo,'') END DeliveryNote,                   -- ONG02  --CS06
   SKU.SKUGROUP,                                            -- ONG03
   0,                                                       -- ONG03
   ORDERS.DeliveryDate,                                     -- ONG04
   ORDERS.OrderGroup,                                       -- ONG05
   CASE WHEN SKU.SUSR4 = 'SSCC' THEN   --NJOW01
              '**Scan Serial No** '
             ELSE
             ''
   END,
   ISNULL(LOC.LogicalLocation,''), -- ChewKP01
   ISNULL(LOTATTRIBUTE.Lottable03, '') --NJOW01
   ,CASE WHEN  @c_VASLBLValue = '1' AND CS.Sku = PICKDETAIL.Sku THEN ISNULL(RTRIM(ST.SUSR5),'')    --(Wan01)
                                 ELSE '' END,                                                       --(Wan01)
   CASE WHEN ISNULL(SC.Svalue,'') = '1' AND SKU.Sku <> SKU.RetailSku AND ISNULL(SKU.RetailSku,'') <> '' THEN
                ISNULL(SKU.RetailSku,'')
   ELSE '' END AS RetailSku
   ,CASE WHEN LEFT(ORDERS.Userdefine10,3) = 'YFD' AND SKU.SKUGroup = 'YFG' THEN
        'YFG' ELSE '' END AS Internalflag --NJOW04
   ,CASE WHEN MAX(ISNULL(CL1.Code,'')) = '' AND MIN(PICKDETAIL.UOM) IN (1,2) AND MAX(ISNULL(CL3.Code,'')) <> '' THEN '*' ELSE '' END AS scancaseidflag --NJOW05
 	 ,CASE WHEN ISNULL(CL2.Code,'') <> '' THEN 'Y' ELSE 'N' END AS showbarcodeflag --NJOW05
 	 ,'' AS udf01                                                                  --(Cs03)
 	 ,ISNULL(ORDERS.UserDefine04,'')                                               --(CS04)
 	 ,CASE WHEN ISNULL(CL5.Code,'') <> '' THEN 'Y' ELSE 'N' END AS showfield --CS05
 	 ,ISNULL(substring(OD.userdefine05,1,1),'') AS ODUDF05                     --CS05
 	 ,CASE WHEN ISNULL(CL6.Code,'') <> '' THEN 'Y' ELSE 'N' END AS showbuyerpo --CS06
 	 ,''  AS cskuudf04                                                         --CS06                                                 
   FROM PICKDETAIL (NOLOCK)
   JOIN ORDERS (NOLOCK) ON (PICKDETAIL.Orderkey = ORDERS.Orderkey)
   JOIN ORDERDETAIL OD (NOLOCK) ON (OD.Orderkey = PICKDETAIL.Orderkey                                          --(CS05)
                                   AND OD.OrderLineNumber=PICKDETAIL.OrderLineNumber                           --(CS05)
                                   AND OD.Sku = PICKDETAIL.Sku AND OD.StorerKey=PICKDETAIL.Storerkey)          --(CS05)
   JOIN WAVEDETAIL (NOLOCK) ON (PICKDETAIL.Orderkey = WAVEDETAIL.Orderkey)
   JOIN LOTATTRIBUTE (NOLOCK) ON (PICKDETAIL.Lot = LOTATTRIBUTE.Lot)
   JOIN SKU (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey AND PICKDETAIL.Sku = SKU.Sku)
   JOIN PACK (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
   JOIN LOC (NOLOCK) ON (LOC.LOC = PICKDETAIL.LOC)    -- ChewKP01
   LEFT OUTER JOIN ROUTEMASTER (NOLOCK) ON (ORDERS.Route = ROUTEMASTER.Route)
   --(Wan01) - START
   LEFT OUTER JOIN STORER ST WITH (NOLOCK) ON (ST.Storerkey = ORDERS.Consigneekey)
   LEFT OUTER JOIN CONSIGNEESKU CS WITH (NOLOCK) ON (CS.Consigneekey = ST.Storerkey)
                                                 AND(CS.Sku = PICKDETAIL.Sku)
   --(Wan01) - END
   LEFT OUTER JOIN v_storerconfig2 SC WITH (NOLOCK) ON ORDERS.Storerkey = SC.Storerkey AND SC.Configkey = 'DELNOTE06_RSKU'
   LEFT OUTER JOIN CODELKUP CL1 (NOLOCK) ON (SKU.Class = CL1.Code AND CL1.Listname = 'MHCSSCAN') --NJOW05
   LEFT OUTER JOIN CODELKUP CL2 (NOLOCK) ON (PICKDETAIL.Storerkey = CL2.Storerkey AND CL2.Code = 'SHOWBARCODE' 
                                          AND CL2.Listname = 'REPORTCFG' AND CL2.Long = 'r_dw_print_wave_pickslip_04' AND ISNULL(CL2.Short,'') <> 'N') --NJOW05
   LEFT OUTER JOIN CODELKUP CL3 (NOLOCK) ON (PICKDETAIL.Storerkey = CL3.Storerkey AND CL3.Code = 'SHOWSCNFG' 
                                          AND CL3.Listname = 'REPORTCFG' AND CL3.Long = 'r_dw_print_wave_pickslip_04' AND ISNULL(CL3.Short,'') <> 'N') --NJOW05
   LEFT OUTER JOIN CODELKUP CL4 (NOLOCK) ON (PICKDETAIL.Storerkey = CL4.Storerkey AND CL4.Code = 'PRTSKUDESC' 
                                          AND CL4.Listname = 'REPORTCFG' AND CL4.Long = 'r_dw_print_wave_pickslip_04' AND ISNULL(CL4.Short,'') <> 'N') --NJOW06    
   LEFT OUTER JOIN CODELKUP CL5 (NOLOCK) ON (PICKDETAIL.Storerkey = CL5.Storerkey AND CL5.Code = 'SHOWFIELD' 
                                          AND CL5.Listname = 'REPORTCFG' AND CL5.Long = 'r_dw_print_wave_pickslip_04' AND ISNULL(CL5.Short,'') <> 'N') --CS05            
      LEFT OUTER JOIN CODELKUP CL6 (NOLOCK) ON (PICKDETAIL.Storerkey = CL6.Storerkey AND CL6.Code = 'SHOWBUYERPO' 
                                          AND CL6.Listname = 'REPORTCFG' AND CL6.Long = 'r_dw_print_wave_pickslip_04' AND ISNULL(CL6.Short,'') <> 'N') --CS06                                                                                                                                                                                                                                                   
   WHERE (WAVEDETAIL.Wavekey = @c_wavekey)
-- AND (PICKDETAIL.PickMethod = '8' OR PICKDETAIL.PickMethod = '')      -- ONG01
   GROUP BY ORDERS.Orderkey,
   ORDERS.ExternOrderkey,
   WAVEDETAIL.WaveKey,
   ISNULL(ORDERS.StorerKey, ''),
   ISNULL(ORDERS.Invoiceno, ''),
   ISNULL(ORDERS.Route, ''),
   ISNULL(ROUTEMASTER.Descr, ''),
   ISNULL(dbo.fnc_RTrim(ORDERS.ConsigneeKey), ''),
   ISNULL(dbo.fnc_RTrim(ORDERS.C_Company), ''),
   ISNULL(dbo.fnc_RTrim(ORDERS.C_Address1), ''),
   ISNULL(dbo.fnc_RTrim(ORDERS.C_Address2), ''),
   ISNULL(dbo.fnc_RTrim(ORDERS.C_Address3), ''),
   ISNULL(dbo.fnc_RTrim(ORDERS.C_Zip), ''),
   ISNULL(dbo.fnc_RTrim(ORDERS.C_City), ''),
   SKU.Sku,
   --ISNULL(SKU.Descr,''),
   CASE WHEN ISNULL(CL4.Code,'') <> '' AND ISNULL(SKU.Notes1,'') <> '' THEN SKU.Notes1 ELSE ISNULL(SKU.Descr,'') END,  --NJOW06
   PICKDETAIL.Lot,
   ISNULL(LOTATTRIBUTE.Lottable01, ''),
   ISNULL(Convert(NVARCHAR(10), LOTATTRIBUTE.Lottable04,112), '01/01/1900'),
   ISNULL(PICKDETAIL.Loc, ''),
   ISNULL(PACK.Qty, 0),
   ISNULL(PACK.PackUOM3, ''),
   ISNULL(PACK.CaseCnt, 0),
   ISNULL(PACK.InnerPack, 0),
   ISNULL(ORDERS.Capacity, 0.00),
   ISNULL(ORDERS.GrossWeight, 0.00),
   CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes, '')),
   CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes2, '')),
   ISNULL(LOTATTRIBUTE.Lottable02, ''),         -- ONG02
   CASE WHEN ISNULL(CL6.Code,'') = '' OR ISNULL(CL6.Code,'') = 'N' THEN ISNULL(Orders.DeliveryNote,'') 
    ELSE ISNULL(orders.buyerpo,'') END,                    -- ONG02    --CS06
   SKU.SKUGROUP,                                -- ONG03
   ORDERS.DeliveryDate,                         -- ONG04
   ORDERS.OrderGroup,                                       -- ONG05
   CASE WHEN SKU.SUSR4 = 'SSCC' THEN   --NJOW01
              '**Scan Serial No** '
             ELSE
             ''
   END,
   ISNULL(LOC.LogicalLocation,''),   -- ChewKP01
   ISNULL(LOTATTRIBUTE.Lottable03, '') --NJOW01
   ,CASE WHEN  @c_VASLBLValue = '1' AND CS.Sku = PICKDETAIL.Sku THEN ISNULL(RTRIM(ST.SUSR5),'')    --(Wan01)
                                 ELSE '' END,                                                       --(Wan01)
   CASE WHEN ISNULL(SC.Svalue,'') = '1' AND SKU.Sku <> SKU.RetailSku AND ISNULL(SKU.RetailSku,'') <> '' THEN
                ISNULL(SKU.RetailSku,'')                                                       --(Wan01)
   ELSE '' END
   ,CASE WHEN LEFT(ORDERS.Userdefine10,3) = 'YFD' AND SKU.SKUGroup = 'YFG' THEN
        'YFG' ELSE '' END --NJOW04
 	 ,CASE WHEN ISNULL(CL2.Code,'') <> '' THEN 'Y' ELSE 'N' END --NJOW05
 	 ,ISNULL(ORDERS.UserDefine04,'')                                               --(CS04)
 	 ,CASE WHEN ISNULL(CL5.Code,'') <> '' THEN 'Y' ELSE 'N' END --CS05
 	 ,ISNULL(substring(OD.userdefine05,1,1),'')                   --CS05
 	 ,CASE WHEN ISNULL(CL6.Code,'') <> '' THEN 'Y' ELSE 'N' END --CS06

   SELECT @n_err = @@ERROR
   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3
      IF @@TRANCOUNT >= 1
      BEGIN
         ROLLBACK TRAN
         GOTO FAILURE
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
         GOTO FAILURE
      END
   END

   -- ONG03 BEGIN
   /* Re-calculate SKUGROUP BEGIN*/
   DECLARE C_Pickslip CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT Orderkey, SKUGROUP, SUM(Qty)
   FROM  #TEMP_PICK
   GROUP BY Orderkey, SKUGROUP

   OPEN C_Pickslip
   FETCH NEXT FROM C_Pickslip INTO @c_Orderkey, @c_SKUGROUP, @n_Qty

   WHILE @@FETCH_STATUS <> -1
   BEGIN
   	
   	   /*CS03 Start*/
   IF EXISTS (SELECT * FROM CODELKUP CLK WITH (NOLOCK) 
              WHERE listname = 'REPORTCFG' 
              AND code = 'afroutedes'
              AND long ='r_dw_print_wave_pickslip_04'
              AND storerkey = @c_StorerKey)
    BEGIN
    	
    SELECT TOP 1 @c_getudf01 = C.udf01
                ,@c_getUdf02 = C.udf02  
    FROM Codelkup C WITH (NOLOCK)  
    WHERE C.listname='REPORTCFG'  
    AND code = 'afroutedes'
    AND long ='r_dw_print_wave_pickslip_04'
    AND c.Storerkey = @c_Storerkey            
      
    SET @c_ExecStatements = ''  
    SET @c_ExecArguments = '' 
    SET @c_condition = ''
    SET @c_ordudf05 = ''    --(CS03a)
    
    IF  ISNULL(@c_getUdf02,'') <> ''
    BEGIN
    	SET @c_condition = 'AND ' + @c_getUdf02
    END
    ELSE 
    BEGIN
    	SET @c_condition = 'AND Orders.userdefine05=''*'''
    END	
  
    SET @c_ExecStatements = N'SELECT @c_ordudf05 =' + @c_getudf01 + ' from Orders (nolock) where orderkey=@c_OrderKey '  
    SET @c_ExecAllStatements = @c_ExecStatements + @c_condition
  
    SET @c_ExecArguments = N'@c_getudf01    NVARCHAR(100) '  
                          +',@c_OrderKey    NVARCHAR(30)'  
                          +',@c_ordudf05    NVARCHAR(20) OUTPUT'  
  
     EXEC sp_ExecuteSql @c_ExecAllStatements   
                      , @c_ExecArguments  
                      , @c_getudf01      
                      , @c_OrderKey  
                      , @c_ordudf05 OUTPUT  
  
  
    --IF @b_debug = '1'  
    --    BEGIN  
    --      PRINT ' @c_ordudf05 : ' + @c_ordudf05  
    --    END   
    	
    END 
             
   
   /*CS03 End*/
   
   /*CS06 Start*/
   
   SET @c_CSKUUDF04 = ''
   
    SELECT @c_CSKUUDF04 = udf04 
    FROM consigneesku csku WITH (nolock) 
    JOIN Orders O WITH (NOLOCK) ON O.storerkey = csku.StorerKey AND o.ConsigneeKey = csku.ConsigneeKey
    where O.OrderKey =  @c_Orderkey
    AND sku in (select top 1 sku
               from orderdetail(nolock)
		 where orderkey=@c_Orderkey)

   
   /*CS06 End*/
   	
   	
   	
      UPDATE #TEMP_PICK
      SET SKUGroupQty = @n_Qty
         ,UDF01 = @c_ordudf05                --CS03
         ,CSKUUDF04 = @c_CSKUUDF04           --CS06
      WHERE Orderkey = @c_Orderkey
      AND SKUGroup = @c_SKUGROUP
      FETCH NEXT FROM C_Pickslip INTO @c_Orderkey, @c_SKUGROUP, @n_Qty
   END
   CLOSE C_Pickslip
   DEALLOCATE C_Pickslip
   /* Re-calculate SKUGROUP END*/
   -- ONG03 END

   -- Check if any pickslipno with NULL value
   SELECT @n_pickslips_required = COUNT(DISTINCT OrderKey)
   FROM #TEMP_PICK
   WHERE ISNULL(RTRIM(PickSlipNo),'') = '' -- SOS# 283436

   IF @@ERROR <> 0
   BEGIN
      GOTO FAILURE
   END
   ELSE IF @n_pickslips_required > 0
   BEGIN
      EXECUTE nspg_GetKey 'PICKSLIP', 9, @c_pickheaderkey OUTPUT, @b_success OUTPUT, @n_err  OUTPUT, @c_errmsg OUTPUT, 0, @n_pickslips_required

      INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, WaveKey, PickType, Zone, TrafficCop)
      SELECT 'P' + RIGHT ( REPLICATE ('0', 9) +
      dbo.fnc_LTrim( dbo.fnc_RTrim(
      STR(CAST(@c_pickheaderkey AS INT) + (SELECT COUNT(DISTINCT OrderKey)
                                           FROM #TEMP_PICK AS Rank
                                           WHERE Rank.OrderKey < #TEMP_PICK.OrderKey
                                           AND ISNULL(RTRIM(Rank.PickSlipNo),'') = '' ) -- SOS# 283436
          ) -- str
          )) -- dbo.fnc_RTrim
          , 9)
         , OrderKey, WaveKey, '0', '8', ''
      FROM #TEMP_PICK
      WHERE ISNULL(RTRIM(PickSlipNo),'') = '' -- SOS# 283436
      GROUP By WaveKey, OrderKey

      UPDATE #TEMP_PICK
      SET PickSlipNo = PICKHEADER.PickHeaderKey
      FROM PICKHEADER (NOLOCK)
      WHERE PICKHEADER.WaveKey = #TEMP_PICK.Wavekey
      AND   PICKHEADER.OrderKey = #TEMP_PICK.OrderKey
      AND   PICKHEADER.Zone = '8'
      AND   ISNULL(RTRIM(#TEMP_PICK.PickSlipNo),'') = '' -- SOS# 283436
   END

   GOTO SUCCESS


 FAILURE:
   DELETE FROM #TEMP_PICK
 SUCCESS:
   -- (YokeBeen01) - Start
   -- Do Auto Scan-in when Configkey is setup.
   SET @c_StorerKey = ''
   SET @c_PickSlipNo = ''

   SELECT DISTINCT @c_StorerKey = StorerKey
     FROM #TEMP_PICK (NOLOCK)

   IF EXISTS (SELECT 1 FROM STORERCONFIG (NOLOCK) WHERE CONFIGKEY = 'AUTOSCANIN'
                 AND SValue = '1' AND StorerKey = @c_StorerKey)
   BEGIN
      DECLARE C_AutoScanPickSlip CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT PickSlipNo
        FROM #TEMP_PICK (NOLOCK)

      OPEN C_AutoScanPickSlip
      FETCH NEXT FROM C_AutoScanPickSlip INTO @c_PickSlipNo

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM PICKINGINFO (NOLOCK) Where PickSlipNo = @c_PickSlipNo)
         BEGIN
            INSERT INTO PICKINGINFO (PickSlipNo, ScanInDate, PickerID, ScanOutDate)
            VALUES (@c_PickSlipNo, GetDate(), sUser_sName(), NULL)

            IF @@ERROR <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 61900
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) +
                                  ': Insert PickingInfo Failed. (nsp_GetPickSlipWave_04)' + ' ( ' +
                                  ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
         END -- PickSlipNo Does Not Exist

         FETCH NEXT FROM C_AutoScanPickSlip INTO @c_PickSlipNo
      END
      CLOSE C_AutoScanPickSlip
      DEALLOCATE C_AutoScanPickSlip
   END -- Configkey is setup
   -- (YokeBeen01) - End
   
   

   SELECT PickSlipNo ,OrderKey ,ExternOrderkey ,WaveKey ,StorerKey  ,InvoiceNo ,Route  ,RouteDescr ,ConsigneeKey
         ,C_Company ,C_Addr1 ,C_Addr2 ,C_Addr3 ,C_PostCode, C_City, Sku ,SkuDescr ,Lot ,Lottable01 ,Lottable04
         ,SUM(Qty) AS Qty ,Loc ,MasterUnit ,LowestUOM ,CaseCnt ,InnerPack ,Capacity ,GrossWeight ,PrintedFlag ,Notes1
         ,Notes2 ,Lottable02 ,DeliveryNote ,SKUGROUP ,SkuGroupQty ,DeliveryDate ,OrderGroup  ,scanserial, LogicalLoc, Lottable03
         ,LabelFlag, RetailSku             --(Wan01)
         ,Internalflag --NJOW04
         ,scancaseidflag, showbarcodeflag,ISNULL(UDF01,'') AS udf01 --NJOW05     --CS03
         ,ISNULL(OHUDF04,'') AS OHUDF04                                          --CS04
         ,showfield,ODUDF05,showbuyerpo,CSKUUDF04                                --CS05   --CS06
         FROM #TEMP_PICK 
         --CS02 Start
   GROUP BY PickSlipNo ,OrderKey ,ExternOrderkey ,WaveKey ,StorerKey  ,InvoiceNo ,Route  ,RouteDescr ,ConsigneeKey
         ,C_Company ,C_Addr1 ,C_Addr2 ,C_Addr3 ,C_PostCode, C_City, Sku ,SkuDescr ,Lot ,Lottable01 ,Lottable04
         ,Loc ,MasterUnit ,LowestUOM ,CaseCnt ,InnerPack ,Capacity ,GrossWeight ,PrintedFlag ,Notes1
         ,Notes2 ,Lottable02 ,DeliveryNote ,SKUGROUP ,SkuGroupQty ,DeliveryDate ,OrderGroup  ,scanserial, LogicalLoc, Lottable03
         ,LabelFlag, RetailSku             --(Wan01)
         ,Internalflag --NJOW04
         ,scancaseidflag, showbarcodeflag ,UDF01,OHUDF04 ,showfield,ODUDF05       --CS05
         ,showbuyerpo,CSKUUDF04                                                   --Cs06
         --CS02 End
   ORDER BY PickSlipNo, LogicalLoc, Loc, Sku, SkuGroup   -- ChewKP01
                                                        
   DROP TABLE #TEMP_PICK

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_starttcnt
         BEGIN
            COMMIT TRAN
         END
      END

      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'nsp_GetPickSlipWave_04'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO