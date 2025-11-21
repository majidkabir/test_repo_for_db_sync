SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
	 
/************************************************************************/    
/* Store Procedure: isp_GetPickSlipWave15_2                             */    
/* Creation Date: 21-MAR-2018                                           */    
/* Copyright: IDS                                                       */    
/* Written by: CSCHONG                                                  */    
/*                                                                      */    
/* Purpose: Pickslip WMS-6220                                           */    
/*                                                                      */    
/* Called By: r_dw_print_wave_pickslip_15                               */    
/*                                                                      */    
/* PVCS Version: 1.1                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/*		Date         Author    Ver.  Purposes                           */
/*   04-OCT-2018	 ZCCHAN	    1	  updates							*/
/************************************************************************/    
	 
CREATE PROC [dbo].[isp_GetPickSlipWave15_2] (@c_wavekey NVARCHAR(10))     
 AS    
 BEGIN    
	SET NOCOUNT ON     
	SET ANSI_NULLS OFF
	SET QUOTED_IDENTIFIER OFF     
	SET CONCAT_NULL_YIELDS_NULL OFF   
	
	 
	 DECLARE @c_pickheaderkey        NVARCHAR(10),    
				@n_continue             int,    
				@c_errmsg               NVARCHAR(255),    
				@b_success              int,    
				@n_err                  int,    
				@n_pickslips_required   int ,
				@n_starttcnt            INT,
				@c_FirstTime            NVARCHAR(1),
				@c_PrintedFlag          NVARCHAR(1),
				@c_PickSlipNo           NVARCHAR(20),
				@c_storerkey            NVARCHAR(20)
	 
		 SELECT @n_starttcnt=@@TRANCOUNT, @n_continue=1, @b_success=0, @n_err=0, @c_errmsg=''
		 
		 
	CREATE TABLE #TEMP_PICK15_2
		( SCompany        NVARCHAR(45) NULL,
		OrderKey          NVARCHAR(10) NULL,
		WaveKey           NVARCHAR(10) NULL,
		Brand             NVARCHAR(30) NULL,   -- (c.short)
		CUDF04            NVARCHAR(45) NULL,
		DeliveryDate      datetime NULL,      
		BuyerPO           NVARCHAR(30) NULL,    
		ExternOrderkey    NVARCHAR(30) NULL,  
		Qty               INT,   
		Pickheaderkey     NVARCHAR(20) NULL,   
		CheckPack         NVARCHAR(5) NULL, 
		PVolume           FLOAT DEFAULT(0),
		SVolume           FLOAT DEFAULT(0),
		Storerkey         NVARCHAR(20) NULL,
		Userdefine09	  NVARCHAR(10) NULL,
		C_City			  NVARCHAR(45) NULL,
		C_Company		  NVARCHAR(45) NULL,
		Cnt_sku			  INT,				       
		Capacity		  FLOAT)

		
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
		
		BEGIN TRAN
		
		INSERT INTO #TEMP_PICK15_2
		SELECT ST.Company AS SCompany,
				 ORDERS.OrderKey AS Orderkey,
				 wave.wavekey AS Wavekey,
				 ISNULL(c.Short,'') AS Brand,
				 MAX(CSKU.UDF04) AS CUDF04,
					CONVERT(NVARCHAR(10),ORDERS.DeliveryDate,111) AS DeliveryDate,
					ORDERS.BuyerPO AS BuyerPO,
					ORDERS.ExternOrderKey AS ExternOrderkey,
					SUM(OD.qtyallocated) AS ORIQty,
					(SELECT PICKHEADER.PickHeaderKey FROM PICKHEADER (NOLOCK)
				WHERE PICKHEADER.Wavekey = @c_wavekey
				AND PICKHEADER.OrderKey = ORDERS.OrderKey
				AND PICKHEADER.ZONE = '8') , 
			  CASE WHEN ISNULL(PACK.PACKKEY,'') <> '' THEN 'Y' ELSE 'N' END AS CheckPack
			  ,ISNULL(round(sum(DISTINCT(widthuom3*lengthuom3*heightuom3)/nullif(casecnt,0)),1),0) AS PVolume
			  ,ISNULL(round(sum(DISTINCT sku.[length]*Width*Height/nullif(PackQtyIndicator,0)),1),0)  AS SVolume
			  ,ORDERS.storerkey AS Storerkey
			  ,Orders.Userdefine09 AS Userdefine09 --
			  ,Orders.C_City AS C_City
			  ,Orders.C_Company AS C_Company
			  ,Count(Distinct(OD.SKU)) AS Cnt_sku
			  ,Orders.Capacity / 27000 AS Capacity
			FROM ORDERS (NOLOCK)  
			JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey=ORDERS.orderkey
			 --JOIN LOC (NOLOCK) ON LOC.LOC = PICKDETAIL.LOC 
			 JOIN WAVEDETAIL (NOLOCK) ON WAVEDETAIL.OrderKey = ORDERS.OrderKey 
			 JOIN WAVE (NOLOCK) ON WAVE.WaveKey = WAVEDETAIL.WaveKey 
			--	JOIN PICKHEADER (NOLOCK) ON PICKHEADER.wavekey = WAVEDETAIL.wavekey AND PICKHEADER.orderkey = WAVEDETAIL.OrderKey
			 JOIN SKU (NOLOCK) ON SKU.StorerKey = OD.StorerKey AND SKU.SKU = OD.SKU 
			 JOIN STORER ST WITH (NOLOCK) ON ST.StorerKey=ORDERS.ConsigneeKey
			 LEFT JOIN CODELKUP C WITH (NOLOCK) ON c.LISTNAME='LORBRD' AND C.Code=ORDERS.[Stop]
									  AND c.Storerkey=ORDERS.StorerKey
			 LEFT JOIN Consigneesku CSKU WITH (NOLOCK) ON Csku.ConsigneeKey=ORDERS.ConsigneeKey 
												 AND CSKU.StorerKey=ORDERS.StorerKey 
												 AND CSKU.SKU = OD.sku                    
			 JOIN PACK (NOLOCK) ON PACK.PackKey = SKU.PackKey
		 WHERE wave.WaveKey = @c_wavekey
		 and OD.qtyallocated > 0
		GROUP BY ST.Company,wave.wavekey,c.Short,--CSKU.UDF04,
		ORDERS.DeliveryDate,ORDERS.OrderKey,ORDERS.ExternOrderKey,
		ORDERS.BuyerPO,--,PICKHEADER.PickHeaderKey 
		ORDERS.UserDefine09,ORDERS.C_City,ORDERS.C_Company,
		ORDERS.Capacity
		,CASE WHEN ISNULL(PACK.PACKKEY,'') <> '' THEN 'Y' ELSE 'N' END
		,ORDERS.storerkey--,CSKU.UDF04
		ORDER BY wave.wavekey--,CASE WHEN ISNULL(CSKU.UDF04,'') <> '' THEN 1 ELSE 0 END desc

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
	
	SELECT @n_pickslips_required = COUNT(DISTINCT OrderKey)
	FROM #TEMP_PICK15_2
	WHERE ISNULL(RTRIM(Pickheaderkey),'') = '' 

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
														 FROM #TEMP_PICK15_2 AS Rank
														 WHERE Rank.OrderKey < #TEMP_PICK15_2.OrderKey
														 AND ISNULL(RTRIM(Rank.Pickheaderkey),'') = '' ) 
			 ) -- str
			 )) -- dbo.fnc_RTrim
			 , 9)
			, OrderKey, WaveKey, '0', '8', ''
		FROM #TEMP_PICK15_2
		WHERE ISNULL(RTRIM(Pickheaderkey),'') = '' -- SOS# 283436
		GROUP By WaveKey, OrderKey

		UPDATE #TEMP_PICK15_2
		SET Pickheaderkey = PICKHEADER.PickHeaderKey
		FROM PICKHEADER (NOLOCK)
		WHERE PICKHEADER.WaveKey = #TEMP_PICK15_2.Wavekey
		AND   PICKHEADER.OrderKey = #TEMP_PICK15_2.OrderKey
		AND   PICKHEADER.Zone = '8'
		AND   ISNULL(RTRIM(#TEMP_PICK15_2.Pickheaderkey),'') = '' -- SOS# 283436
	END

	GOTO SUCCESS


 FAILURE:
	DELETE FROM #TEMP_PICK15_2
 SUCCESS:
	-- (YokeBeen01) - Start
	-- Do Auto Scan-in when Configkey is setup.
	SET @c_StorerKey = ''
	SET @c_PickSlipNo = ''

	SELECT DISTINCT @c_StorerKey = StorerKey
	  FROM #TEMP_PICK15_2 (NOLOCK)

	IF EXISTS (SELECT 1 FROM STORERCONFIG (NOLOCK) WHERE CONFIGKEY = 'AUTOSCANIN'
					  AND SValue = '1' AND StorerKey = @c_StorerKey)
	BEGIN
		DECLARE C_AutoScanPickSlip CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
		SELECT DISTINCT Pickheaderkey
		  FROM #TEMP_PICK15_2 (NOLOCK)

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
	
	

	SELECT tp.SCompany, tp.OrderKey, tp.WaveKey, tp.Brand, tp.CUDF04,
			 tp.DeliveryDate, tp.BuyerPO, tp.ExternOrderkey, tp.Qty, tp.Pickheaderkey,
			 tp.CheckPack, tp.PVolume, 
			 tp.SVolume, tp.Storerkey, tp.Userdefine09, tp.C_City, tp.C_Company,
			 tp.Cnt_sku, tp.Capacity
	FROM #TEMP_PICK15_2 AS tp
	--ORDER BY tp.WaveKey, case when tp.CUDF04 = NULL THEN 'ZZZZZ' ELSE tp.CUDF04 end ,tp.Pickheaderkey,
	--ORDER BY tp.ExternOrderkey,tp.C_Company,tp.Capacity
	ORDER BY tp.Brand,tp.C_City, tp.DeliveryDate,tp.ExternOrderkey,tp.C_Company,tp.Capacity
																		  
	DROP TABLE #TEMP_PICK15_2

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

		EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'nsp_GetPickSlipWave_15_1'
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