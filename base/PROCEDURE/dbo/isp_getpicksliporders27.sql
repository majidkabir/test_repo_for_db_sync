SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_GetPickSlipOrders27                        	   */
/* Creation Date: 2008-10-22                            		            */
/* Copyright: IDS                                                       */
/* Written by: YTwan                          			    	  				*/
/*                                                                      */
/* Purpose:  Pickslip for BBRAUN														*/
/*                                                                      */
/* Input Parameters:  @c_loadkey  - Loadkey 										*/
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_print_pickorder27       				*/
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:  RMC Normal Pickslip from LoaddPlan                       */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 01-Aug-2012  NJOW01    1.0   251353-Add Storerkey                    */
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */
/************************************************************************/

CREATE PROC [dbo].[isp_GetPickSlipOrders27] (@c_loadkey NVARCHAR(10)) 
AS
BEGIN
	SET NOCOUNT ON			
   SET QUOTED_IDENTIFIER OFF	
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF


	DECLARE @c_pickheaderkey	NVARCHAR(10),
		@n_continue			  int,
		@c_errmsg			  NVARCHAR(255),
		@b_success			  int,
		@n_err				  int,
		@c_sku				  NVARCHAR(20),
		@n_qty				  int,
		@c_loc				  NVARCHAR(10),
		@n_cases				  int,
		@n_perpallet		  int,
		@c_storer			  NVARCHAR(15),
		@c_orderkey			  NVARCHAR(10),
		@c_ConsigneeKey     NVARCHAR(15),
		@c_Company          NVARCHAR(45),
		@c_Addr1            NVARCHAR(45),
		@c_Addr2            NVARCHAR(45),
		@c_Addr3            NVARCHAR(45),
		@c_PostCode         NVARCHAR(15),
		@c_Route            NVARCHAR(10),
		@c_Route_Desc       NVARCHAR(60),  
		@c_TrfRoom          NVARCHAR(5),   
		@c_Notes1           NVARCHAR(60),
		@c_Notes2           NVARCHAR(60),
		@c_SkuDesc          NVARCHAR(60),
		@n_CaseCnt          int,
		@n_PalletCnt        int,
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
		@c_firsttime		  NVARCHAR(1),
		@c_logicalloc       NVARCHAR(18),
		@c_Lottable02       NVARCHAR(18),		 
		@d_Lottable04       datetime,
		@n_packpallet       int,
		@n_packcasecnt      int,
		@c_externorderkey   NVARCHAR(50),    --tlting_ext
		@n_pickslips_required int,  
		@c_areakey			  NVARCHAR(10),
		@c_dischargeplace	  NVARCHAR(30),		 
		@c_invoiceno		  NVARCHAR(20)
 	   	   	   		   
		DECLARE @c_PrevOrderKey NVARCHAR(10),
		      @n_Pallets      int,
		      @n_Cartons      int,
		      @n_Eaches       int,
		      @n_UOMQty       int

		CREATE TABLE #TEMP_PICK
		(  PickSlipNo       NVARCHAR(10) NULL,
			LoadKey          NVARCHAR(10),
			OrderKey         NVARCHAR(10),
			ConsigneeKey     NVARCHAR(15),
			Company          NVARCHAR(45),
			Addr1            NVARCHAR(45) NULL,
			Addr2            NVARCHAR(45) NULL,
			Addr3            NVARCHAR(45) NULL,
			PostCode         NVARCHAR(15) NULL,
			Route            NVARCHAR(10) NULL,
			Route_Desc       NVARCHAR(60) NULL,  
			TrfRoom          NVARCHAR(5)  NULL,   
			Notes1           NVARCHAR(60) NULL,
			Notes2           NVARCHAR(60) NULL,
			LOC              NVARCHAR(10) NULL, 
			ID					  NVARCHAR(18) NULL,  		 
			SKU              NVARCHAR(20),
			SkuDesc          NVARCHAR(60),
			Qty              int,
			TempQty1	  		  int,
			TempQty2	        int,
			PrintedFlag      NVARCHAR(1) NULL,
			Zone             NVARCHAR(1),
			PgGroup          int,
			RowNum           int,
			Lot		        NVARCHAR(10),
			Carrierkey       NVARCHAR(60) NULL,
			VehicleNo        NVARCHAR(10) NULL,
			Lottable02       NVARCHAR(18) NULL,		 
			Lottable04       datetime NULL,
			packpallet	     int,
			packcasecnt	     int, 
			packinner		  int,					 
			packeaches		  int,  					 
			externorderkey   NVARCHAR(50) NULL,   --tlting_ext
			LogicalLoc       NVARCHAR(18) NULL,  
			Areakey			  NVARCHAR(10) NULL,      
			UOM				  NVARCHAR(10),           
			Pallet_cal		  int,  
			Cartons_cal		  int,  
			inner_cal		  int,					  
			Each_cal			  int,  
			Total_cal		  int,  					 
			DeliveryDate	  datetime NULL,
			Lottable01		  NVARCHAR(18) NULL,		 
			Lottable03		  NVARCHAR(18) NULL,		 
			Lottable05		  datetime NULL,	   
			DischargePlace	  NVARCHAR(30) NULL,		 
			InvoiceNo		  NVARCHAR(20) NULL,		 
			Pltcnt			  int NULL, -- SOS101659
		  Storerkey     NVARCHAR(15) NULL)

		INSERT INTO #TEMP_PICK
			(  PickSlipNo,          LoadKey,         OrderKey,			ConsigneeKey,
				Company,             Addr1,           Addr2,				PgGroup,
				Addr3,               PostCode,        Route,
				Route_Desc,          TrfRoom,         Notes1,			RowNum,
				Notes2,              LOC,             ID,					SKU,
				SkuDesc,             Qty,	           TempQty1,
				TempQty2,	         PrintedFlag,     Zone,
				Lot,		    			CarrierKey,      VehicleNo,		Lottable02,
				Lottable04, 	    	packpallet,	     packcasecnt,	   packinner,		
				packeaches,          externorderkey,  LogicalLoc,		Areakey,				UOM,	
				Pallet_cal,			   Cartons_cal,	  inner_cal,      Each_cal,			Total_cal,	
				DeliveryDate,		   Lottable01,      Lottable03,     Lottable05 ,		
				DischargePlace ,     InvoiceNo,       Pltcnt,			Storerkey ) 
		SELECT
				(	SELECT PICKHEADERKEY FROM PICKHEADER WITH (NOLOCK)
					WHERE ExternOrderKey = @c_LoadKey 
					AND OrderKey = PickDetail.OrderKey 
					AND ZONE = '3'),
				@c_LoadKey as LoadKey,                 
				PickDetail.OrderKey,                            
				ISNULL(ORDERS.ConsigneeKey, '') AS ConsigneeKey,  
				ISNULL(ORDERS.c_Company, '')    AS Company,   
				ISNULL(ORDERS.C_Address1,'')    AS Addr1,            
				ISNULL(ORDERS.C_Address2,'')    AS Addr2,
				0 AS PgGroup,                              
				ISNULL(ORDERS.C_Address3,'') AS Addr3,            
				ISNULL(ORDERS.C_Zip,'')      AS PostCode,
				ISNULL(ORDERS.Route,'')      AS Route,         
				ISNULL(RouteMaster.Descr, '') Route_Desc,       
				ORDERS.Door AS TrfRoom,
				CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes,  '')) Notes1,                                    
				0 AS RowNo, 
				CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes2, '')) Notes2,
				PickDetail.loc,   
				PickDetail.id, 			
				PickDetail.sku,                         
				ISNULL(Sku.Descr,'') AS SkuDescr,                  
				SUM(PickDetail.qty)  AS Qty,
				CASE PickDetail.UOM
						 WHEN '1' THEN PACK.Pallet   
						 WHEN '2' THEN PACK.CaseCnt    
						 WHEN '3' THEN PACK.InnerPack  
						 ELSE 1   
                   END           AS UOMQty,
				0 AS TempQty2,
				ISNULL((SELECT Distinct 'Y' FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @c_Loadkey AND  Zone = '3')
                   , 'N') AS PrintedFlag, 
				'3' Zone,
				Pickdetail.Lot,                         
				ORDERS.DischargePlace CarrierKey,                                  
				'' AS VehicleNo,
				LotAttribute.Lottable02,                
				ISNULL(LotAttribute.Lottable04, '19000101') Lottable04,        
				PACK.Pallet,
				PACK.CaseCnt,
				pack.innerpack,	
				PACK.Qty,					
				ORDERS.ExternOrderKey AS ExternOrderKey,               
				ISNULL(LOC.LogicalLocation, '')  AS LogicalLocation, 
				ISNULL(AreaDetail.AreaKey, '00') AS Areakey,     
				ISNULL(OrderDetail.UOM, '')      AS UOM,            
				Pallet_cal = CASE Pack.Pallet WHEN 0 THEN 0 
 								                         ELSE FLOOR(SUM(PickDetail.qty) / Pack.Pallet)  
 																 END,
				Cartons_cal = 0,
				inner_cal   = 0,
				Each_cal    = SUM(PickDetail.qty),
				Total_cal   = SUM(pickdetail.qty),
				ISNULL(ORDERS.DeliveryDate, '19000101') DeliveryDate,        
				LotAttribute.Lottable01,								 
				LotAttribute.Lottable03,								 
				ISNULL(LotAttribute.Lottable05	, '19000101'),	 
				ORDERS.DischargePlace,									 
				ORDERS.InvoiceNo,
				0,
				ORDERS.Storerkey										 
       FROM pickdetail     WITH (NOLOCK)
 	    JOIN ORDERS         WITH (NOLOCK) ON pickdetail.orderkey = orders.orderkey
 	    JOIN lotattribute   WITH (NOLOCK) ON pickdetail.lot = lotattribute.lot
	    JOIN loadplandetail WITH (NOLOCK) ON pickdetail.orderkey = loadplandetail.orderkey
	    JOIN orderdetail    WITH (NOLOCK) ON pickdetail.orderkey = orderdetail.orderkey 
			    								    AND pickdetail.orderlinenumber = orderdetail.orderlinenumber			
  	    JOIN storer         WITH (NOLOCK) ON pickdetail.storerkey = storer.storerkey
 	    JOIN sku            WITH (NOLOCK) ON pickdetail.sku = sku.sku and pickdetail.storerkey = sku.storerkey
 	    JOIN pack           WITH (NOLOCK) ON pickdetail.packkey = pack.packkey
 	    JOIN loc            WITH (NOLOCK) ON pickdetail.loc = loc.loc
 	    LEFT outer JOIN routemaster WITH (NOLOCK) ON orders.route = routemaster.route
 	    LEFT outer JOIN areadetail  WITH (NOLOCK) ON loc.putawayzone = areadetail.putawayzone
      WHERE PickDetail.Status < '5'  
        AND LoadPlanDetail.LoadKey = @c_LoadKey
   GROUP BY PickDetail.OrderKey,                            
     ISNULL(ORDERS.ConsigneeKey, ''),
     ISNULL(ORDERS.c_Company, ''),   
     ISNULL(ORDERS.C_Address1,''),
     ISNULL(ORDERS.C_Address2,''),
     ISNULL(ORDERS.C_Address3,''),
     ISNULL(ORDERS.C_Zip,''),
     ISNULL(ORDERS.Route,''),
     ISNULL(RouteMaster.Descr, ''),
     ORDERS.Door,
     CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes,  '')),                                    
     CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes2, '')),
     PickDetail.loc,   
	  PickDetail.id,  		 
     PickDetail.sku,                         
     ISNULL(Sku.Descr,''),                  
     CASE PickDetail.UOM
          WHEN '1' THEN PACK.Pallet   
          WHEN '2' THEN PACK.CaseCnt    
          WHEN '3' THEN PACK.InnerPack  
          ELSE 1  
          END,
     Pickdetail.Lot,                         
     LotAttribute.Lottable02,                
     ISNULL(LotAttribute.Lottable04, '19000101'),        
     PACK.Pallet,
     PACK.CaseCnt,
	  pack.innerpack,		
     PACK.Qty,					
     ORDERS.ExternOrderKey,
     ISNULL(LOC.LogicalLocation, ''),  
	  ISNULL(AreaDetail.AreaKey, '00'),    
	  ISNULL(OrderDetail.UOM, ''),          
     ISNULL(ORDERS.DeliveryDate, '19000101'),
	  LotAttribute.Lottable01,		
	  LotAttribute.Lottable03,		
	  ISNULL(LotAttribute.Lottable05 , '19000101'),		
	  ORDERS.DischargePlace,										
	  ORDERS.InvoiceNo,
	  ORDERS.Storerkey											
	

		UPDATE #temp_pick
		SET cartons_cal = CASE packcasecnt
									WHEN 0 THEN 0
									ELSE FLOOR(total_cal/packcasecnt) - ((packpallet*pallet_cal)/packcasecnt)
									END

		UPDATE #temp_pick
		SET 	 Pltcnt = TTLPLT.PltCnt
		FROM   ( SELECT Orderkey, PltCnt = COUNT(DISTINCT ISNULL(ID, 0))
					FROM  #temp_Pick
					WHERE ID > ''
					GROUP BY Orderkey ) As TTLPLT
		WHERE #temp_pick.Orderkey = TTLPLT.Orderkey

		BEGIN TRAN  
		-- Uses PickType as a Printed Flag  
		
		UPDATE PickHeader WITH (ROWLOCK) SET PickType = '1', TrafficCop = NULL 
       WHERE ExternOrderKey = @c_LoadKey 
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
		ELSE BEGIN  
         IF @@TRANCOUNT > 0   
         BEGIN  
             COMMIT TRAN  
         END  
         ELSE BEGIN  
             SELECT @n_continue = 3  
             ROLLBACK TRAN  
         END  
		END  

		SELECT @n_pickslips_required = COUNT(DISTINCT OrderKey) 
		FROM #TEMP_PICK
		WHERE PickSlipNo IS NULL

		IF @@ERROR <> 0
		BEGIN
		   GOTO FAILURE
		END
		ELSE IF @n_pickslips_required > 0
		BEGIN
			EXECUTE nspg_GetKey 'PICKSLIP', 9, @c_pickheaderkey OUTPUT, @b_success OUTPUT, @n_err  OUTPUT, @c_errmsg OUTPUT, 
                 0, @n_pickslips_required
			
			INSERT INTO PICKHEADER (PickHeaderKey,    OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)
         SELECT 'P' + RIGHT ( REPLICATE ('0', 9) + 
             			         LTRIM( RTRIM(
                								STR( 
                   							CAST(@c_pickheaderkey AS INT) + ( SELECT count(DISTINCT orderkey) 
                                                     							 FROM #TEMP_PICK AS Rank 
                                                     							 WHERE Rank.OrderKey < #TEMP_PICK.OrderKey )
														))) 
                            , 9) 
               ,OrderKey
					,LoadKey
					,'0'
					,'3'
					,''
           FROM #TEMP_PICK WHERE PickSlipNo IS NULL
       GROUP By LoadKey, OrderKey

         UPDATE #TEMP_PICK 
         	SET PickSlipNo = PICKHEADER.PickHeaderKey
           FROM PICKHEADER WITH (NOLOCK)
          WHERE PICKHEADER.ExternOrderKey = #TEMP_PICK.LoadKey
            AND PICKHEADER.OrderKey = #TEMP_PICK.OrderKey
            AND PICKHEADER.Zone = '3'
			   AND #TEMP_PICK.PickSlipNo IS NULL
		END
     	GOTO SUCCESS

 FAILURE:
     DELETE FROM #TEMP_PICK
 SUCCESS:
     SELECT * FROM #TEMP_PICK  
	  DROP Table #TEMP_PICK  
END

GO