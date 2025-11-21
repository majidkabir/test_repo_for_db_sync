SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  nsp_GetPickSlipWave_06                        		*/
/* Creation Date: 07-Aug-2007                          						*/
/* Copyright: IDS                                                       */
/* Written by: ONGGB                                    						*/
/*                                                                      */
/* Purpose: Conso Pickslip for IDSTW- JJVC from Wave Plan (FBR 80647)	*/
/*                                                                      */
/* Called By: r_dw_print_wave_pickslip_06                               */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author     Purposes                                      */
/* 2007-08-07  ONG01      Modify from nsp_GetPickSlipWave_04     			*/
/* 28-Jan-2019  TLTING_ext 1.1 enlarge externorderkey field length      */
/************************************************************************/

CREATE PROC [dbo].[nsp_GetPickSlipWave_06] (@c_wavekey NVARCHAR(10)) 
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
	DECLARE	@n_continue		int,
	@c_errmsg 	    		 NVARCHAR(255),
	@b_success	    			int,
 	@n_err	  	    			int,
	@n_starttcnt				int, 
	@n_pickslips_required	int,
	@c_PickHeaderKey    	 NVARCHAR(10),
	@c_FirstTime			 NVARCHAR(1),
	@c_PrintedFlag			 NVARCHAR(1),
	@c_Orderkey				 NVARCHAR(10),			
	@c_SKUGROUP				 NVARCHAR(10), 			
	@n_Qty						int,					
	@c_StorerKey            NVARCHAR(15),			
	@c_PickSlipNo           NVARCHAR(10)				

	SELECT @n_starttcnt=@@TRANCOUNT, @n_continue=1, @b_success=0, @n_err=0, @c_errmsg=''

	CREATE TABLE #TEMP_PICK
		( PickSlipNo      NVARCHAR(10) NULL,
		OrderKey          NVARCHAR(10),
		ExternOrderkey    NVARCHAR(50),   --tlting_ext
		WaveKey           NVARCHAR(10),
		StorerKey		 NVARCHAR(15),
		InvoiceNo 	 	   NVARCHAR(10),
		Route             NVARCHAR(10) NULL,
		RouteDescr		 NVARCHAR(60) NULL,
		ConsigneeKey	 NVARCHAR(15) NULL,
		C_Company         NVARCHAR(45) NULL,
		C_Addr1           NVARCHAR(45) NULL,
		C_Addr2           NVARCHAR(45) NULL,
		C_Addr3           NVARCHAR(45) NULL,
		C_PostCode    	 NVARCHAR(18) NULL,
		Sku		 		   NVARCHAR(20) NULL,
		SkuDescr   	 	   NVARCHAR(60) NULL,
		Lot				 NVARCHAR(10),
		Lottable01        NVARCHAR(18) NULL,	-- Batch No
		Lottable04			datetime NULL,	-- Expiry Date
		Qty              	int,				-- PickDetail.Qty
		Loc				 NVARCHAR(10) NULL, 
		MasterUnit			int,
		LowestUOM		 NVARCHAR(10),
		CaseCnt				int,
		InnerPack			int,
		Capacity				float,
		GrossWeight			float,
		PrintedFlag       NVARCHAR(1),
		Notes1            NVARCHAR(60)	NULL,
		Notes2			 NVARCHAR(60)	NULL,
      Lottable02        NVARCHAR(18) NULL,    
      DeliveryNote      NVARCHAR(10) NULL,    
		SKUGROUP 		 NVARCHAR(10) NULL,		
		SkuGroupQty			int,					
		DeliveryDate		datetime NULL,		
		OrderGroup 		 NVARCHAR(20) NULL, 
		LogicalLocation NVARCHAR(18) NULL)			-- ONG01


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
   UPDATE PICKHEADER
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
	ISNULL(RTRIM(ORDERS.ConsigneeKey), ''),
	ISNULL(RTRIM(ORDERS.C_Company), ''),
	ISNULL(RTRIM(ORDERS.C_Address1), ''),
	ISNULL(RTRIM(ORDERS.C_Address2), ''),
	ISNULL(RTRIM(ORDERS.C_Address3), ''),
	ISNULL(RTRIM(ORDERS.C_Zip), ''),	
	SKU.Sku,
	ISNULL(SKU.Descr,'') AS SkuDescr,
	MIN(PICKDETAIL.Lot) Lot,			-- Not Required
	ISNULL(MIN(LOTATTRIBUTE.Lottable01), ''),
	ISNULL(CONVERT(NVARCHAR(10), MIN(LOTATTRIBUTE.Lottable04) ,112), '01/01/1900'),
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
	ISNULL(MIN(LOTATTRIBUTE.Lottable02), '') Lottable02,         	
   Orders.DeliveryNote,                                    	
	SKU.SKUGROUP,															
	0, 																		
	ORDERS.DeliveryDate, 												
	ORDERS.OrderGroup,
	Loc.LogicalLocation 
	FROM PICKDETAIL (NOLOCK)
	JOIN ORDERS (NOLOCK) ON (PICKDETAIL.Orderkey = ORDERS.Orderkey)
	JOIN WAVEDETAIL (NOLOCK) ON (PICKDETAIL.Orderkey = WAVEDETAIL.Orderkey)   
	JOIN LOTATTRIBUTE (NOLOCK) ON (PICKDETAIL.Lot = LOTATTRIBUTE.Lot)  
	JOIN SKU (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey AND PICKDETAIL.Sku = SKU.Sku)
	JOIN PACK (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
	LEFT OUTER JOIN ROUTEMASTER (NOLOCK) ON (ORDERS.Route = ROUTEMASTER.Route)
	JOIN LOC (NOLOCK) ON Loc.Loc = PICKDETAIL.Loc 
 	WHERE (WAVEDETAIL.Wavekey = @c_wavekey)
	GROUP BY ORDERS.Orderkey,
	ORDERS.ExternOrderkey,
	WAVEDETAIL.WaveKey,
	ISNULL(ORDERS.StorerKey, ''),
	ISNULL(ORDERS.Invoiceno, ''),
	ISNULL(ORDERS.Route, ''),
	ISNULL(ROUTEMASTER.Descr, ''),
	ISNULL(RTRIM(ORDERS.ConsigneeKey), ''),
	ISNULL(RTRIM(ORDERS.C_Company), ''),
	ISNULL(RTRIM(ORDERS.C_Address1), ''),
	ISNULL(RTRIM(ORDERS.C_Address2), ''),
	ISNULL(RTRIM(ORDERS.C_Address3), ''),
	ISNULL(RTRIM(ORDERS.C_Zip), ''),
	SKU.Sku,
	ISNULL(SKU.Descr,''),
-- 	PICKDETAIL.Lot,
-- 	ISNULL(LOTATTRIBUTE.Lottable01, ''),
-- 	ISNULL(Convert(char(10), LOTATTRIBUTE.Lottable04,112), '01/01/1900'),
	ISNULL(PICKDETAIL.Loc, ''),
	ISNULL(PACK.Qty, 0),
	ISNULL(PACK.PackUOM3, ''),
	ISNULL(PACK.CaseCnt, 0),
	ISNULL(PACK.InnerPack, 0),
	ISNULL(ORDERS.Capacity, 0.00),
	ISNULL(ORDERS.GrossWeight, 0.00),
	CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes, '')),
	CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes2, '')),
-- 	ISNULL(LOTATTRIBUTE.Lottable02, ''),         
   Orders.DeliveryNote,                         
	SKU.SKUGROUP,											
	ORDERS.DeliveryDate,									
	ORDERS.OrderGroup,
	Loc.LogicalLocation 


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

	/* Re-calculate SKUGROUP BEGIN*/
	DECLARE C_Pickslip CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT Orderkey, SKUGROUP, SUM(Qty)
   FROM  #TEMP_PICK	
	GROUP BY Orderkey, SKUGROUP 
	   
	OPEN C_Pickslip 	
	FETCH NEXT FROM C_Pickslip INTO @c_Orderkey, @c_SKUGROUP, @n_Qty
	
	WHILE @@FETCH_STATUS <> -1
	BEGIN
		UPDATE #TEMP_PICK
		SET SKUGroupQty = @n_Qty
		WHERE Orderkey = @c_Orderkey 
		AND SKUGroup = @c_SKUGROUP
		FETCH NEXT FROM C_Pickslip INTO @c_Orderkey, @c_SKUGROUP, @n_Qty
	END
   CLOSE C_Pickslip
   DEALLOCATE C_Pickslip 
	/* Re-calculate SKUGROUP END*/
	
	-- Check if any pickslipno with NULL value
	SELECT @n_pickslips_required = COUNT(DISTINCT OrderKey) 
	FROM #TEMP_PICK
	WHERE PickSlipNo IS NULL

	IF @@ERROR <> 0
	BEGIN
		GOTO FAILURE
	END
	ELSE IF @n_pickslips_required > 0
	BEGIN
		EXECUTE nspg_GetKey 'PICKSLIP', 9, @c_pickheaderkey OUTPUT, @b_success OUTPUT, @n_err  OUTPUT, @c_errmsg OUTPUT, 0, @n_pickslips_required
		
		INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, WaveKey, PickType, Zone, TrafficCop)
		SELECT 'P' + RIGHT ( REPLICATE ('0', 9) + 
		LTRIM( RTRIM(
		STR(CAST(@c_pickheaderkey AS INT) + (SELECT COUNT(DISTINCT OrderKey) 
		                                     FROM #TEMP_PICK AS Rank 
		                                     WHERE Rank.OrderKey < #TEMP_PICK.OrderKey ) 
		    ) -- str
		    )) -- rtrim
			 , 9) 
			, OrderKey, WaveKey, '0', '8', ''
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
                                  ': Insert PickingInfo Failed. (nsp_GetPickSlipWave_06)' + ' ( ' + 
                                  ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
            END
         END -- PickSlipNo Does Not Exist

   		FETCH NEXT FROM C_AutoScanPickSlip INTO @c_PickSlipNo 
	   END
      CLOSE C_AutoScanPickSlip
      DEALLOCATE C_AutoScanPickSlip 
   END -- Configkey is setup
	-- (YokeBeen01) - End

   SELECT * FROM #TEMP_PICK ORDER BY PickSlipNo, Loc, Sku, SkuGroup
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

      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'nsp_GetPickSlipWave_06'
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