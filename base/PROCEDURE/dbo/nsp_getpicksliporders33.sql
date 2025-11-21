SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_GetPickSlipOrders33                            */
/* Creation Date: 19-MAR-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: GTGOH                                                    */
/*                                                                      */
/* Purpose: Discrete Pickslip for IDSCN	- Carter (SOS#164713)			*/
/*                                                                      */
/* Called By: r_dw_print_pickorder33                                    */ 
/*                                                                      */
/* Parameters: (Input)  @c_loadKey   = Load Number                      */
/*                                                                      */
/* PVCS Version: 1.0	                                                   */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 28-Jan-2019  TLTING_ext 1.1 enlarge externorderkey field length      */
/************************************************************************/

CREATE PROCEDURE [dbo].[nsp_GetPickSlipOrders33]
   @c_LoadKey   NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_PickHeaderKey  NVARCHAR(10),  
      @n_continue         int,  
      @c_errmsg           NVARCHAR(255),  
      @b_success          int,  
      @n_err              int,  
      @c_OrderKey         NVARCHAR(10),  
      @c_StorerKey        NVARCHAR(15),  
      @c_SKU              NVARCHAR(20),  
      @c_SKUDesc          NVARCHAR(60),  
      @n_Qty              int,  
      @c_ConsigneeKey     NVARCHAR(15),  
      @c_Company          NVARCHAR(45),  
      @c_Addr1            NVARCHAR(45),  
      @c_Addr2            NVARCHAR(45),  
      @c_Addr3            NVARCHAR(45),  
      @c_Addr4            NVARCHAR(45),  
      @c_PostCode         NVARCHAR(15),  
      @c_Route            NVARCHAR(10),  
      @c_Route_Desc       NVARCHAR(60),   
      @c_Notes1           NVARCHAR(60),  
      @c_Notes2           NVARCHAR(60),  
      @n_CaseCnt          int,  
		@n_InnerPack		  int,     
      @c_ExternOrderKey   NVARCHAR(50),    --tlting_ext
      @c_Zone             NVARCHAR(1),  
      @c_PrintedFlag      NVARCHAR(1),  
      @c_FirstTime        NVARCHAR(1),  
		@c_BuyerPO			  NVARCHAR(20), 
      @c_UserDefine02     NVARCHAR(20),
	   @c_Lottable03		  NVARCHAR(18),
		@n_BOMQty			  int ,
		@c_M_Country        NVARCHAR(30)

   CREATE TABLE #Temp_Pick  
   (  PickSlipNo       NVARCHAR(10) NULL,  
      LoadKey          NVARCHAR(10) NULL,  
      OrderKey         NVARCHAR(10) NULL,  
      ConsigneeKey     NVARCHAR(15) NULL,  
      Company          NVARCHAR(45) NULL,  
      Addr1            NVARCHAR(45) NULL,  
      Addr2            NVARCHAR(45) NULL,  
      Addr3            NVARCHAR(45) NULL,  
      Addr4            NVARCHAR(45) NULL,  
      PostCode         NVARCHAR(18) NULL,  
      Route            NVARCHAR(10) NULL,  
      Route_Desc       NVARCHAR(60) NULL,  
      Notes1           NVARCHAR(60) NULL,  
      Notes2           NVARCHAR(60) NULL,  
      SKU              NVARCHAR(20) NULL,  
      SkuDesc          NVARCHAR(60) NULL,  
      Qty              int,  
      TempQty1			  int,  
      TempQty2         int,  
      ExternOrderKey   NVARCHAR(50) NULL,    --tlting_ext
      Zone             NVARCHAR(1)  NULL,  
      PrintedFlag      NVARCHAR(1)  NULL,  
		BuyerPO			  NVARCHAR(20) NULL, 
      UserDefine02     NVARCHAR(20) NULL,
		Lottable03		  NVARCHAR(18),
		BOMQty			  int,
		M_Country        NVARCHAR(30) NULL )   
         
   SELECT @n_continue = 1   
	
	DECLARE @n_TotalIntegrity INT    -- (ChewKP01)

	DECLARE @tTempCheckIntegrity TABLE (
      SKU			 NVARCHAR(20) NULL,
      PDQTY				INT      NULL,
      BOMQTY			INT		NULL, -- (ChewKP01)
      ChkIntegrity	INT		NULL  -- (ChewKP01)
      )

	SET @n_TotalIntegrity = 0 -- (ChewKP01)

 	-- Uses PickType as a Printed Flag
   IF EXISTS(SELECT 1 FROM PickHeader WITH (NOLOCK)  
   WHERE ExternOrderKey = @c_loadkey  
	AND   Zone = '3')  
   BEGIN  
      SELECT @c_FirstTime = 'N'  
      SELECT @c_PrintedFlag = 'Y'  
   END  
   ELSE  
   BEGIN  
      SELECT @c_FirstTime = 'Y'  
      SELECT @c_PrintedFlag = 'N'  
   END -- Record Not Exists  

  	IF @n_continue = 1 or @n_continue = 2
	BEGIN
	      SELECT @b_success = 0
	      
         SELECT @b_success = 1 FROM LoadPlanDetail (NOLOCK)
			WHERE LoadKey = @c_LoadKey AND RTRIM(ISNULL(OrderKey,'')) <> ''

         IF @b_Success <> 1
         BEGIN
            SET @n_err			= 600002
            SET @c_errmsg     = 'Order Not exist in Load Plan for ' + @c_LoadKey
				SELECT @n_continue = 3
				GOTO EXIT_SP 
			END
		
			-- Validate PickDetail Quantity is integral multiple quantity in BOM
			IF @n_continue = 1 or @n_continue = 2
			BEGIN

				INSERT INTO @tTempCheckIntegrity		-- (ChewKP01) 
				SELECT  PICKDETAIL.SKU , PICKDETAIL.Qty , BILLOFMATERIAL.Qty ,  PICKDETAIL.Qty % BILLOFMATERIAL.Qty 
				FROM LoadPlan (NOLOCK)
				INNER JOIN LoadPlanDetail (NOLOCK) ON (LoadPlan.LoadKey = LoadPlanDetail.LoadKey)
				INNER JOIN ORDERS (NOLOCK) ON (LoadPlanDetail.Loadkey = ORDERS.Loadkey 
													AND LoadPlanDetail.Orderkey = ORDERS.Orderkey ) 
				INNER JOIN PICKDETAIL (NOLOCK) ON (LoadPlanDetail.OrderKey = PICKDETAIL.OrderKey)
--				INNER JOIN PICKHEADER (NOLOCK) ON (PICKHEADER.ExternOrderKey = LoadPlan.LoadKey AND 
--															  PICKHEADER.OrderKey = PICKDETAIL.OrderKey)
				INNER JOIN LOC (NOLOCK) ON (PICKDETAIL.LOC = LOC.LOC)
				INNER JOIN SKU (NOLOCK) ON (SKU.StorerKey = PICKDETAIL.StorerKey AND SKU.SKU = PICKDETAIL.SKU)
				INNER JOIN PACK (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
				INNER JOIN LOTATTRIBUTE (NOLOCK) ON (PICKDETAIL.LOT = LOTATTRIBUTE.LOT)
				INNER JOIN BILLOFMATERIAL (NOLOCK) ON (LOTATTRIBUTE.Lottable03 = BILLOFMATERIAL.SKU
														AND PICKDETAIL.SKU = BILLOFMATERIAL.ComponentSKU )
				WHERE LoadPlanDetail.LoadKey = @c_LoadKey 

				SELECT @n_TotalIntegrity = SUM(ChkIntegrity) FROM @tTempCheckIntegrity -- (ChewKP01)

	         IF @n_TotalIntegrity > 0  -- (ChewKP01)
				BEGIN
					SET @n_err			= 600003
            	SET @c_errmsg     = 'Quantity of component SKU in PickDetail is not integral ' 
					SELECT @n_continue = 3
					GOTO EXIT_SP 
				END
	
		END				

	END -- IF @n_continue = 1 or @n_continue = 2

   BEGIN TRAN  
   -- Uses PickType as a Printed Flag  
   UPDATE PickHeader  
   SET PickType = '1',  
       TrafficCop = NULL  
   WHERE ExternOrderKey = @c_loadkey  
   AND Zone = '3'  
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
  
   DECLARE pick_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT PickDetail.OrderKey,   
      PickDetail.StorerKey,   
      PickDetail.SKU,       
      SUM(PickDetail.Qty),  
		LOTATTRIBUTE.Lottable03
		--SUM(BILLOFMATERIAL.Qty) 
   FROM PickDetail WITH (NOLOCK)  
   INNER JOIN LoadPlanDetail WITH (NOLOCK) ON (PickDetail.OrderKey = LoadPlanDetail.OrderKey)  
	INNER JOIN LOTATTRIBUTE (NOLOCK) ON (PICKDETAIL.LOT = LOTATTRIBUTE.LOT)
	--INNER JOIN BILLOFMATERIAL (NOLOCK) ON (LOTATTRIBUTE.Lottable03 = BILLOFMATERIAL.SKU
	--					AND PICKDETAIL.SKU = BILLOFMATERIAL.ComponentSKU )
   WHERE LoadPlanDetail.LoadKey = @c_loadkey  
   GROUP BY PickDetail.OrderKey,   
      PickDetail.StorerKey,   
      PickDetail.SKU,
		LOTATTRIBUTE.Lottable03
   ORDER BY PickDetail.Orderkey  
         
   OPEN pick_cur  
  
   FETCH NEXT FROM pick_cur INTO @c_OrderKey, @c_StorerKey, @c_SKU, @n_Qty, @c_Lottable03
              
   WHILE (@@FETCH_STATUS <> -1)  
   BEGIN  
      SELECT @c_ConsigneeKey = ORDERS.ConsigneeKey,  
			@c_Company      = ORDERS.c_Company,  
			@c_Addr1        = ORDERS.C_Address1,  
			@c_Addr2        = ORDERS.C_Address2,  
			@c_Addr3        = ORDERS.C_Address3,  
			@c_Addr4        = ORDERS.C_Address4,  
			@c_PostCode     = ORDERS.C_Zip,  
			@c_Notes1       = CONVERT(NVARCHAR(60), ORDERS.Notes),  
			@c_Notes2       = CONVERT(NVARCHAR(60), ORDERS.Notes2),  
			@c_ExternOrderKey = ORDERS.ExternOrderKey,  
			@c_BuyerPO    = ORDERS.BuyerPO,
			@c_UserDefine02 = ISNULL(ORDERS.Userdefine02, ''),
			@c_M_Country    = ORDERS.M_Country
      FROM   ORDERS WITH (NOLOCK)    
      WHERE  ORDERS.OrderKey = @c_OrderKey  
     
      SELECT @c_Route = IsNULL(LoadPlan.Route, '')  
      FROM   LoadPlan WITH (NOLOCK)  
      WHERE  Loadkey = @c_LoadKey  
        
      SELECT @c_Route_Desc  = IsNULL(RouteMaster.Descr, '')  
      FROM   RouteMaster WITH (NOLOCK)  
      WHERE  Route = @c_Route  
        
      SELECT @c_SKUDesc = IsNULL(SKU.Descr,'')  
      FROM   SKU WITH (NOLOCK)  
      WHERE  SKU = @c_Lottable03  
          
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
      IF @c_Route_Desc    IS NULL SELECT @c_Route_Desc = ''  
		IF @c_BuyerPO		  IS NULL SELECT @c_BuyerPO = '' 
           
      -- Select casecnt and innerpack instead of based on UOM, then store into TempQty1 and TempQty2   
      SELECT @n_CaseCnt = 0, @n_InnerPack = 0  
      SELECT @n_CaseCnt = PACK.CaseCnt,  
         @n_InnerPack = PACK.InnerPack  
      FROM PACK WITH (NOLOCK)  
      INNER JOIN SKU WITH (NOLOCK) ON (PACK.PackKey = SKU.PackKey)  
      WHERE  SKU.SKU = @c_Lottable03  
        
      SELECT @c_PickHeaderKey = NULL  
           
      SELECT @c_PickHeaderKey = ISNULL(PickHeaderKey, '')   
      FROM PickHeader WITH (NOLOCK)   
      WHERE ExternOrderKey = @c_loadkey  
		AND   Zone = '3'  
      AND   OrderKey = @c_OrderKey  

		-- Get BOM QTY --
		SET @n_BOMQty  = 0

		SELECT @n_BOMQty = SUM(BOM.QTY)
		FROM BillOfMaterial BOM WITH (NOLOCK)
		WHERE BOM.Storerkey = @c_Storerkey
		AND   BOM.SKU = @c_Lottable03


            
      INSERT INTO #Temp_Pick  
         (PickSlipNo,         LoadKey,          OrderKey,         ConsigneeKey,  
         Company,             Addr1,            Addr2,            Addr3,  
         Addr4,               PostCode,         Route,            Route_Desc,  
         Notes1,              Notes2,           SKU,              SkuDesc,  
         Qty,                 TempQty1,         TempQty2,         ExternOrderKey,  
         Zone,                PrintedFlag,		BuyerPO,          UserDefine02,
			Lottable03,				BOMQty,           M_Country)
      VALUES   
         (@c_PickHeaderKey,   @c_LoadKey,       @c_OrderKey,     @c_ConsigneeKey,  
          @c_Company,         @c_Addr1,         @c_Addr2,        @c_Addr3,  
          @c_Addr4,           @c_PostCode,      @c_Route,        @c_Route_Desc,  
          @c_Notes1,          @c_Notes2,        @c_SKU,          @c_SKUDesc,  
          @n_Qty,             @n_CaseCnt,       @n_InnerPack,    @c_ExternOrderKey,  
          '3',                @c_PrintedFlag,   @c_BuyerPO,      @c_UserDefine02,
			 @c_Lottable03,		@n_BOMQty,        @c_M_Country)   
            
         FETCH NEXT FROM pick_cur INTO @c_OrderKey, @c_StorerKey, @c_SKU, @n_Qty, @c_Lottable03
      END  
         
   CLOSE pick_cur     
   DEALLOCATE pick_cur     
  
   DECLARE @n_pickslips_required int,  
          @c_NextNo NVARCHAR(10)   
     
   SELECT @n_pickslips_required = Count(DISTINCT OrderKey)   
   FROM #TEMP_PICK  
   WHERE RTRIM(PickSlipNo) IS NULL OR RTRIM(PickSlipNo) = ''  
   IF @@ERROR <> 0  
   BEGIN  
      GOTO FAILURE  
   END  
   ELSE IF @n_pickslips_required > 0  
   BEGIN  
      EXECUTE nspg_GetKey 'PICKSLIP', 9, @c_NextNo OUTPUT, @b_success OUTPUT, @n_err  OUTPUT, @c_errmsg OUTPUT, 0, @n_pickslips_required  
      IF @b_success <> 1   
         GOTO FAILURE   
        
        
      SELECT @c_OrderKey = ''  
      WHILE 1=1  
      BEGIN  
         SELECT @c_OrderKey = MIN(OrderKey)  
         FROM   #TEMP_PICK   
         WHERE  OrderKey > @c_OrderKey  
         AND    PickSlipNo IS NULL   
           
         IF RTRIM(@c_OrderKey) IS NULL OR RTRIM(@c_OrderKey) = ''  
            BREAK  
           
         IF NOT Exists(SELECT 1 FROM PickHeader WITH (NOLOCK) WHERE OrderKey = @c_OrderKey)  
         BEGIN  
            SELECT @c_PickHeaderKey = 'P' + @c_NextNo   
            SELECT @c_NextNo = RIGHT ( REPLICATE ('0', 9) + LTRIM( RTRIM( STR( CAST(@c_NextNo AS int) + 1))), 9)  
              
            BEGIN TRAN  
            INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)  
            VALUES (@c_PickHeaderKey, @c_OrderKey, @c_LoadKey, '0', '3', '')  
              
            SELECT @n_err = @@ERROR  
            IF @n_err <> 0  
            BEGIN  
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
                  ROLLBACK TRAN  
                  GOTO FAILURE  
               END  
            END -- @n_err <> 0  
         END -- NOT Exists         
      END   -- WHILE  
        
      UPDATE #TEMP_PICK   
      SET PickSlipNo = PICKHEADER.PickHeaderKey  
      FROM  PICKHEADER WITH (NOLOCK)  
      WHERE PICKHEADER.ExternOrderKey = #TEMP_PICK.LoadKey  
      AND   PICKHEADER.OrderKey = #TEMP_PICK.OrderKey  
      AND   PICKHEADER.Zone = '3'  
      AND   #TEMP_PICK.PickSlipNo IS NULL  
  
   END  
   GOTO SUCCESS  
  
 FAILURE:  
  DELETE FROM #TEMP_PICK  
  
 SUCCESS:  
  -- Do Auto Scan-in when only 1 storer found and configkey is setup    
  DECLARE @nCnt int,  
   @cStorerKey NVARCHAR(15)  
   
  IF ( SELECT COUNT(DISTINCT StorerKey) FROM  ORDERS WITH (NOLOCK), LOADPLANDETAIL WITH (NOLOCK)  
     WHERE LOADPLANDETAIL.OrderKey = ORDERS.OrderKey AND LOADPLANDETAIL.LoadKey = @c_loadkey ) = 1  
  BEGIN   
   -- Only 1 storer found  
   SELECT @cStorerKey = ''  
   SELECT @cStorerKey = (SELECT DISTINCT StorerKey   
           FROM   ORDERS WITH (NOLOCK), LOADPLANDETAIL WITH (NOLOCK)  
           WHERE  LOADPLANDETAIL.OrderKey = ORDERS.OrderKey   
           AND   LOADPLANDETAIL.LoadKey = @c_loadkey )  
    
   IF EXISTS (SELECT 1 FROM STORERCONFIG WITH (NOLOCK) WHERE CONFIGKEY = 'AUTOSCANIN' AND  
        SValue = '1' AND StorerKey = @cStorerKey)  
   BEGIN   
    -- Configkey is setup  
    DECLARE @cPickSlipNo NVARCHAR(10)  
   
        SELECT @cPickSlipNo = ''  
        WHILE 1=1  
        BEGIN  
           SELECT @cPickSlipNo = MIN(PickSlipNo)  
           FROM   #TEMP_PICK   
           WHERE  PickSlipNo > @cPickSlipNo  
             
           IF RTRIM(@cPickSlipNo) IS NULL OR RTRIM(@cPickSlipNo) = ''  
              BREAK  
             
           IF NOT Exists(SELECT 1 FROM PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)  
           BEGIN  
              INSERT INTO PickingInfo  (PickSlipNo, ScanInDate, PickerID, ScanOutDate)  
              VALUES (@cPickSlipNo, GetDate(), sUser_sName(), NULL)  
           END            
        END  
   END -- Configkey is setup  
  END -- Only 1 storer found  

	  /*DELETE FROM TEMP_PICK_TEST
   
	  INSERT INTO TEMP_PICK_TEST
	  SELECT * FROM #TEMP_PICK */

	  -- Do the Calculations before return result to PB (ChewKP01)	
     SELECT  PickSlipNo , Loadkey , Orderkey , ConsigneeKey , Company, Addr1, Addr2, Addr3, Addr3, Postcode ,Route,  Route_Desc,  Notes1, notes2,
				 SkuDesc, ExternOrderkey, Zone,PrintedFlag, BuyerPO , Userdefine02, Lottable03,
				(Sum (qty) / bomqty) / tempqty1 as Cartons , (Sum (qty) / bomqty) % tempqty1 as Eaches , M_Country
	  FROM #TEMP_PICK     
	  GROUP BY Lottable03 , SKUDesc,  PickSlipNo , Loadkey , Orderkey , ConsigneeKey , Company, Addr1, Addr2, Addr3, Addr3, Postcode , Route,  Route_Desc, Notes1, notes2,
				ExternOrderkey, Zone,PrintedFlag, BuyerPO , Userdefine02, tempqty1 , BOMQTY, M_Country
	  ORDER BY Lottable03, SKUDesc
	
     DROP Table #TEMP_PICK    

 

   EXIT_SP:

   IF @n_continue=3  -- Error Occured - Process And Return    
   BEGIN    
     SELECT @b_success = 0    
     RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
     RETURN    
   END    
   /* End Return Statement */ 

END /* main procedure */

GO