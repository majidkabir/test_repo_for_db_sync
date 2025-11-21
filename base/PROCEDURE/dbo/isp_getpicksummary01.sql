SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Stored Proc : isp_GetPickSummary_01                                     */
/* Creation Date: 03-05-2017                                               */
/* Copyright: IDS                                                          */
/* Written by: CSCHONG                                                     */
/*                                                                         */
/* Purpose: WMS-1649 - ID-FBR PickList Report By LoadPlan                  */
/*                                                                         */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Local Variables:                                                        */
/*                                                                         */
/* Called By: r_dw_pick_summary01                                          */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 1.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date        Author      Ver   Purposes                                  */
/***************************************************************************/

CREATE PROC [dbo].[isp_GetPickSummary01] (@c_loadkey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
      
	DECLARE     @c_company NVARCHAR(45),
					@c_address1 NVARCHAR(45),
					@c_address2 NVARCHAR(45),
					@c_address3 NVARCHAR(45),
					@c_address4 NVARCHAR(45)
            
                 
	DECLARE @n_starttrancnt INT,
	        @n_continue     INT,
	        @c_errmsg			NVARCHAR(255),
 		     @b_success		INT,
 		     @n_err			   INT,
 		     @c_PrintedFlag  NVARCHAR(1),
 		     @c_Orderkey              NVARCHAR(10),     	   		   
           @c_LocTypeDesc           NVARCHAR(20),      
           @c_Pickdetailkey         NVARCHAR(10),      
           @c_PrevLoadkey           NVARCHAR(10),      
           @c_PrevOrderkey          NVARCHAR(10),      
           @c_PrevLocTypeDesc       NVARCHAR(20),      
           @c_Pickslipno            NVARCHAR(10),      
           @c_Orderlinenumber       NVARCHAR(5),       
           @c_LocTypeCriteria       NVARCHAR(255),     
           @c_ExecStatement         NVARCHAR(4000),     
           @c_putawayzone           NVARCHAR(10), 
           @c_PrevPutawayzone       NVARCHAR(10), 
           @n_Linecount             INT, 
           @c_sku                   NVARCHAR(20), 
           @c_loc                   NVARCHAR(10), 
           @c_id                    NVARCHAR(18), 
           @c_lottable01            NVARCHAR(18), 
           @c_lottable02            NVARCHAR(18), 
           @dt_lottable04           DATETIME,    
           @c_NOSPLITBYLINECNTZONE  NVARCHAR(10)  


	SET @c_company = ''
	SET @c_address1 =''
	SET @c_address2 = ''
	SET @c_address3= ''
	SET @c_address4 = ''
   
   SELECT @n_starttrancnt = @@TRANCOUNT, @n_continue = 1
    --(Kc01) - start
    --check if the loadplan already printed other pickslip type then return error to reject.
    IF EXISTS (SELECT PICKHEADERKEY FROM PICKHEADER WITH (NOLOCK)
             WHERE ExternOrderKey = @c_LoadKey 
             AND ISNULL(RTRIM(OrderKey),'') = ''
             AND ZONE = 'LP')
    BEGIN
       SELECT @n_continue = 3  
       SELECT @n_err = 63500
		 SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Pickslip already printed using Consolidated option. (nsp_GetPickSlipOrders29)'
    END
    
   IF @n_continue = 1 OR @n_continue = 2
	BEGIN
    CREATE TABLE #TEMP_GETPICKSUMM01
       (PickSlipNo       NVARCHAR(10) NULL,
		   LoadKey          NVARCHAR(10) NULL,
		   OrderKey         NVARCHAR(10) NULL,
		   ConsigneeKey     NVARCHAR(15) NULL,
		   Company          NVARCHAR(45) NULL,
		   Addr1            NVARCHAR(45) NULL,
		   Addr2            NVARCHAR(45) NULL,
		   Addr3            NVARCHAR(45) NULL,
		   Addr4            NVARCHAR(45) NULL,
		   City             NVARCHAR(45) NULL,
		   LOC              NVARCHAR(10) NULL, 
		   ID				        NVARCHAR(18) NULL,  		
		   SKU              NVARCHAR(20) NULL,
		   AltSKU           NVARCHAR(20) NULL,
		   SkuDesc          NVARCHAR(60) NULL,
		   Qty              INT,
		   PrintedFlag      NVARCHAR(1)  NULL,
		   LocationTypeDesc NVARCHAR(20) NULL,
		   Lottable01       NVARCHAR(18) NULL,
		   Lottable02       NVARCHAR(18) NULL,
		   Lottable04       datetime NULL,
         externorderkey   NVARCHAR(30) NULL,
         LogicalLoc       NVARCHAR(18) NULL,
         Shelflife        INT,
         MinShelfLife     INT,
         pallet           INT,
         casecnt          INT,
         pickafterdate    DATETIME NULL,
         putawayzone      NVARCHAR(10) NULL,
         LRoute           NVARCHAR(10) NULL,               
         LEXTLoadKey      NVARCHAR(20) NULL, 
         Storerkey        NVARCHAR(20) NULL,               
         Facility         NVARCHAR(5)  DEFAULT (''),
         CustName         NVARCHAR(50) DEFAULT (''))               
       
       INSERT INTO #TEMP_GETPICKSUMM01
            (PickSlipNo,          LoadKey,         OrderKey,		ConsigneeKey,
             Company,             Addr1,           Addr2,			Addr3,
             Addr4,               City,            Loc,           ID,
             SKU,                 AltSKU,          SkuDesc,			Qty,
             PrintedFlag,         Locationtypedesc, Lottable01,	Lottable02, Lottable04,
             ExternOrderkey,      LogicalLoc,	      Shelflife,  Minshelflife,
             pallet,	            casecnt,					pickafterdate,    putawayzone,
             LRoute,LEXTLoadKey,Storerkey,facility,CustName)    

        SELECT RefKeyLookup.PickSlipNo,  
           @c_LoadKey as LoadKey,                 
           ORDERS.OrderKey,     
           IsNull(ORDERS.ConsigneeKey, ''),  
           IsNull(ORDERS.c_Company, ''),   
           IsNull(ORDERS.C_Address1,''),            
           IsNull(ORDERS.C_Address2,''),
           IsNull(ORDERS.C_Address3,''),            
           IsNull(ORDERS.C_Address4,''),            
           IsNull(ORDERS.C_City,''),
           PickDetail.loc,   
           PickDetail.id, 			
           PickDetail.sku,
           Sku.Altsku,
           Sku.Descr,                  
           SUM(PickDetail.qty),
           ISNULL((SELECT Distinct 'Y' FROM PickHeader WITH (NOLOCK) WHERE PickHeaderkey = RefKeyLookup.PickSlipNo
                     AND Orderkey = ORDERS.Orderkey AND  Zone = 'LP') , 'N') AS PrintedFlag, 
           CASE WHEN LOC.Locationtype = 'OTHER' THEN
                'PALLET PICKING LIST'
                ELSE 'EACH PICKING LIST'
           END,
           LotAttribute.Lottable01,                
           LotAttribute.Lottable02,                
           IsNUll(LotAttribute.Lottable04, '19000101'),        
           ORDERS.ExternOrderKey,
           LOC.LogicalLocation,
           SKU.Shelflife,
           STORER.Minshelflife,
           PACK.Pallet,
           PACK.CaseCnt,
           CASE WHEN LEN(LTRIM(LotAttribute.Lottable01)) = 8 THEN
                CASE WHEN ISDATE(SUBSTRING(LTRIM(LotAttribute.Lottable01),5,4)+SUBSTRING(LTRIM(LotAttribute.Lottable01),3,2)+SUBSTRING(LTRIM(LotAttribute.Lottable01),1,2)) = 1 THEN
                    CONVERT(datetime,SUBSTRING(LTRIM(LotAttribute.Lottable01),5,4)+SUBSTRING(LTRIM(LotAttribute.Lottable01),3,2)+SUBSTRING(LTRIM(LotAttribute.Lottable01),1,2)) + SKU.Shelflife - STORER.Minshelflife
                ELSE
                    '19000101'
                END
           ELSE
               '19000101'
           END,
           LOC.PickZone AS Putawayzone,
           Loadplan.Route AS LRoute,                                                
           Loadplan.Externloadkey AS LEXTLoadKey                                   
           ,ORDERS.Storerkey AS storerkey
           ,LOADPLAN.facility AS facility,LOADPLANDETAIL.CustomerName AS CustName                           
 	      FROM LOADPLANDETAIL WITH (NOLOCK) 
 	      JOIN ORDERS WITH (NOLOCK) ON LOADPLANDETAIL.Orderkey = ORDERS.Orderkey
 	      JOIN ORDERDETAIL WITH (NOLOCK) ON ORDERS.Orderkey = ORDERDETAIL.Orderkey
 	      JOIN PICKDETAIL WITH (NOLOCK) ON ORDERDETAIL.orderkey = PICKDETAIL.Orderkey
 	                        AND ORDERDETAIL.Orderlinenumber = PICKDETAIL.Orderlinenumber
 	      JOIN LOTATTRIBUTE WITH (NOLOCK) ON PICKDETAIL.Lot = LOTATTRIBUTE.Lot
 	      JOIN STORER WITH (NOLOCK) ON ORDERS.Storerkey = STORER.Storerkey
 	      JOIN SKU WITH (NOLOCK) ON ORDERDETAIL.Storerkey = SKU.Storerkey 
 	                        AND ORDERDETAIL.Sku = SKU.Sku
 	      JOIN PACK WITH (NOLOCK) ON Sku.Packkey = PACK.Packkey
 	      JOIN LOC WITH (NOLOCK) ON PICKDETAIL.Loc = LOC.Loc
        LEFT OUTER JOIN RefKeyLookup (NOLOCK) ON (RefKeyLookup.PickDetailKey = PICKDETAIL.PickDetailKey)      
        JOIN LOADPLAN WITH (NOLOCK) ON LOADPLAN.loadkey = ORDERDETAIL.loadkey 
        WHERE PICKDETAIL.Status < '5'  
        AND LOADPLANDETAIL.LoadKey = @c_LoadKey
        GROUP BY RefKeyLookup.PickSlipNo,     
           Orders.Orderkey,                    
           IsNull(ORDERS.ConsigneeKey, ''),  
           IsNull(ORDERS.c_Company, ''),   
           IsNull(ORDERS.C_Address1,''),            
           IsNull(ORDERS.C_Address2,''),
           IsNull(ORDERS.C_Address3,''),            
           IsNull(ORDERS.C_Address4,''),            
           IsNull(ORDERS.C_City,''),
           PickDetail.loc,   
           PickDetail.id, 			
           PickDetail.sku,
           Sku.Altsku,
           Sku.Descr,                  
           CASE WHEN Loc.Locationtype = 'OTHER' THEN
                'PALLET PICKING LIST'
                ELSE 'EACH PICKING LIST'
           END,
           LotAttribute.Lottable01,                
           LotAttribute.Lottable02,                
           IsNUll(LotAttribute.Lottable04, '19000101'),        
           ORDERS.ExternOrderKey,
           LOC.LogicalLocation,
           SKU.Shelflife,
           STORER.Minshelflife,
           PACK.Pallet,
           PACK.CaseCnt,
		    	 LOC.PickZone,
           Loadplan.Route ,                                             
           Loadplan.Externloadkey , ORDERS.Storerkey,                                   
           LOADPLAN.facility,LOADPLANDETAIL.CustomerName                                  

     BEGIN TRAN  
     -- Uses PickType as a Printed Flag  
     UPDATE PickHeader WITH (ROWLOCK) SET PickType = '1', TrafficCop = NULL 
     WHERE ExternOrderKey = @c_LoadKey 
     AND Zone = 'LP' 
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
         ELSE BEGIN  
             SELECT @n_continue = 3  
             ROLLBACK TRAN  
         END  
     END  

      SET @c_LoadKey = ''  
      SET @c_OrderKey = ''  
      SET @c_LocTypeDesc = ''
      SET @c_PickDetailKey = ''  
      SET @n_Continue = 1   
      SET @c_Putawayzone = '' 
      SET @n_Linecount = 0 
     
      DECLARE C_Orderkey_LocTypeDesc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
      SELECT DISTINCT TP.LoadKey, TP.OrderKey, TP.LocationTypeDesc,
             TP.Putawayzone, TP.sku, TP.loc, TP.id, TP.lottable01, TP.lottable02, TP.lottable04,  
             CASE WHEN CLR.Code IS NOT NULL THEN 'Y' ELSE 'N' END AS NOSPLITBYLINECNTZONE 
      FROM   #TEMP_GETPICKSUMM01 TP  
      JOIN   ORDERS O (NOLOCK) ON (TP.Orderkey = O.Orderkey) 
      LEFT JOIN CODELKUP CLR (NOLOCK) ON (O.Storerkey = CLR.Storerkey AND CLR.Code = 'NOSPLITBYLINECNTZONE' 
                                          AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_Pick_Summary_01' AND ISNULL(CLR.Short,'') <> 'N') --NJOW04
      WHERE  TP.PickSlipNo IS NULL or TP.PickSlipNo = ''  
      ORDER BY TP.LoadKey, TP.OrderKey, TP.LocationTypeDesc,
               TP.Putawayzone, TP.loc, TP.sku, TP.id --NJOW03

      OPEN C_Orderkey_LocTypeDesc   
     
      FETCH NEXT FROM C_Orderkey_LocTypeDesc INTO @c_LoadKey, @c_OrderKey, @c_LocTypeDesc,
                                                  @c_Putawayzone, @c_sku, @c_loc, @c_id, @c_lottable01, @c_lottable02, @dt_lottable04,  --NJOW03 
                                                  @c_NOSPLITBYLINECNTZONE --NJOW04
     
      WHILE (@@Fetch_Status <> -1)  
      BEGIN -- while 1  
         IF ISNULL(@c_OrderKey, '0') = '0'  
            BREAK  
         
         SELECT @n_Linecount = @n_Linecount + 1 --NJOW03
         
         IF @c_PrevLoadKey <> @c_LoadKey OR   
            @c_PrevOrderKey <> @c_OrderKey OR
            @c_PrevLocTypeDesc <> @c_LocTypeDesc OR
            (@c_PrevPutawayzone <> @c_Putawayzone AND @c_NOSPLITBYLINECNTZONE <> 'Y') OR  --NJOW03 NJOW04
            (@n_Linecount > 15 AND @c_NOSPLITBYLINECNTZONE <> 'Y') --NJOW03 NJOW04
         BEGIN       
--            BEGIN TRAN
            SET @c_PickSlipNo = ''
            SET @n_Linecount = 1 --NJOW03              
     
            EXECUTE nspg_GetKey  
               'PICKSLIP',  
               9,     
               @c_PickSlipNo   OUTPUT,  
               @b_success      OUTPUT,  
               @n_err          OUTPUT,  
               @c_errmsg       OUTPUT  
        
            IF @b_success = 1   
            BEGIN  
               SELECT @c_PickSlipNo = 'P' + @c_PickSlipNo            
               INSERT PICKHEADER (pickheaderkey, OrderKey,    ExternOrderkey, zone, PickType,   Wavekey)  
                          VALUES (@c_PickSlipNo, @c_OrderKey, @c_loadkey, 'LP', '0',  @c_PickSlipNo)  

               SELECT @n_err = @@ERROR  
               IF @n_err <> 0   
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @n_err = 63501
		            SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Insert into PICKHEADER Failed. (isp_GetPickSummary01)'
                  GOTO FAILURE
               END             
            END -- @b_success = 1    
            ELSE   
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @n_err = 63502
	            SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Get PSNO Failed. (isp_GetPickSummary01)'  
               BREAK   
            END   
         END -- @c_PrevLoadKey <> @c_LoadKey OR @c_PrevOrderKey <> @c_OrderKey OR  @c_PrevLocTypeDesc <> @c_LocTypeDesc   
     
         IF @n_Continue = 1   
         BEGIN  
            SET @c_LocTypeCriteria = ''
            SET @c_ExecStatement = ''

            IF @c_LocTypeDesc = 'PALLET PICKING LIST'
            BEGIN
               SET @c_LocTypeCriteria = 'AND LOC.LocationType = ''OTHER'''
            END
            ELSE
            BEGIN
               SET @c_LocTypeCriteria = 'AND LOC.LocationType <> ''OTHER'''
            END

            SET @c_ExecStatement = N'DECLARE C_PickDetailKey CURSOR FAST_FORWARD READ_ONLY FOR ' +
                                    'SELECT PickDetail.PickDetailKey, PickDetail.OrderLineNumber ' +   
                                    'FROM   PickDetail WITH (NOLOCK) ' +
                                    'JOIN   OrderDetail WITH (NOLOCK) ' +                                       
                                    'ON (PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey AND ' + 
                                    'PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber) ' +
                                    'JOIN   LOC WITH (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc) ' +
                                    'JOIN   LOTATTRIBUTE WITH (NOLOCK) ON (PICKDETAIL.Lot = LOTATTRIBUTE.Lot) ' +  
                                    'WHERE  OrderDetail.OrderKey = N''' + @c_OrderKey + '''' +
                                    ' AND    OrderDetail.LoadKey  = N''' + @c_LoadKey  + ''' ' +
                                    ' AND LOC.PickZone = N''' + RTRIM(@c_Putawayzone) + ''' ' +  
                                    ' AND Pickdetail.Sku = N''' + RTRIM(@c_Sku) + ''' ' +  
                                    ' AND Pickdetail.Loc = N''' + RTRIM(@c_Loc) + ''' ' +  
                                    ' AND Pickdetail.Id = N''' + RTRIM(@c_ID) + ''' ' +  
                                    ' AND Lotattribute.Lottable01 = N''' + RTRIM(@c_Lottable01) + ''' ' +  
                                    ' AND Lotattribute.Lottable02 = N''' + RTRIM(@c_Lottable02) + ''' ' +  
                                    ' AND CONVERT(CHAR(10),ISNULL(Lotattribute.Lottable04,''19000101''),112) = ''' + CONVERT(CHAR(10),@dt_Lottable04,112) + ''' ' +  
                                    @c_LocTypeCriteria +
                                    ' ORDER BY PickDetail.PickDetailKey '  
   
            EXEC(@c_ExecStatement)
            OPEN C_PickDetailKey  
     
            FETCH NEXT FROM C_PickDetailKey INTO @c_PickDetailKey, @c_OrderLineNumber   
     
            WHILE @@FETCH_STATUS <> -1  
            BEGIN  
               IF NOT EXISTS (SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @c_PickDetailKey)   
               BEGIN   
                  INSERT INTO RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey)  
                  VALUES (@c_PickDetailKey, @c_PickSlipNo, @c_OrderKey, @c_OrderLineNumber, @c_Loadkey)

                  SELECT @n_err = @@ERROR  
                  IF @n_err <> 0   
                  BEGIN  
                     SELECT @n_continue = 3
                     SELECT @n_err = 63503
	                  SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Insert RefKeyLookup Failed. (isp_GetPickSummary01)'    
                     GOTO FAILURE
                  END                          
               END   
     
               FETCH NEXT FROM C_PickDetailKey INTO @c_PickDetailKey, @c_OrderLineNumber   
            END   
            CLOSE C_PickDetailKey   
            DEALLOCATE C_PickDetailKey        
         END   
                
         UPDATE #TEMP_GETPICKSUMM01  
         SET PickSlipNo = @c_PickSlipNo  
         WHERE OrderKey = @c_OrderKey  
         AND   LoadKey = @c_LoadKey         
         AND   LocationTypeDesc = @c_LocTypeDesc
         AND   Putawayzone = @c_Putawayzone 
         AND   Sku = @c_Sku 
         AND   Loc = @c_Loc 
         AND   ID = @c_ID
         --AND   Lottable01 = @c_Lottable01 
         --AND   Lottable02 = @c_Lottable02 
         --AND   Lottable04 = @dt_Lottable04 
         AND   (PickSlipNo IS NULL OR PickSlipNo = '')  

         SELECT @n_err = @@ERROR  
         IF @n_err <> 0   
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @n_err = 63504
            SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Update #TEMP_GETPICKSUMM01 Failed. (isp_GetPickSummary01)'    
            GOTO FAILURE
         END  

         SET @c_PrevLoadKey = @c_LoadKey   
         SET @c_PrevOrderKey = @c_OrderKey 
         SET @c_PrevLocTypeDesc = @c_LocTypeDesc 
         SET @c_PrevPutawayzone = @c_Putawayzone 
     
         FETCH NEXT FROM C_Orderkey_LocTypeDesc INTO @c_LoadKey, @c_OrderKey, @c_LocTypeDesc,
                                                     @c_Putawayzone, @c_sku, @c_loc, @c_id, @c_lottable01, @c_lottable02, @dt_lottable04,     
        @c_NOSPLITBYLINECNTZONE 

      END -- while 1   
     
      CLOSE C_Orderkey_LocTypeDesc  
      DEALLOCATE C_Orderkey_LocTypeDesc   


     GOTO SUCCESS
     FAILURE:
     DELETE FROM #TEMP_GETPICKSUMM01
     IF CURSOR_STATUS('LOCAL' , 'C_Orderkey_LocTypeDesc') in (0 , 1) 
     BEGIN
        CLOSE C_Orderkey_LocTypeDesc
        DEALLOCATE C_Orderkey_LocTypeDesc
     END

     IF CURSOR_STATUS('GLOBAL' , 'C_PickDetailKey') in (0 , 1) 
     BEGIN
        CLOSE C_PickDetailKey
        DEALLOCATE C_PickDetailKey
     END

     
     SUCCESS:
     
       CREATE TABLE #temp_picksumm01
         ( ID                    INT IDENTITY (1,1),
           LoadKey               NVARCHAR(10),
          C_Company              NVARCHAR(45) NULL,
          Storerkey              NVARCHAR(20),
          Consigneekey           NVARCHAR(20) DEFAULT (''), 
          Facility               NVARCHAR(5)  DEFAULT (''),
          CustName               NVARCHAR(50) DEFAULT (''),
          LPExternOrdKey         NVARCHAR(30) DEFAULT (''),
          C_city                 NVARCHAR(45) DEFAULT (''),
          PHKey                  NVARCHAR(18) DEFAULT (''),
          LocType                NVARCHAR(30) DEFAULT ('')
         )
         
         
         CREATE TABLE #temp_picksumm01OTH
         ( ID                    INT IDENTITY (1,1),
          LoadKey               NVARCHAR(10),
          C_Company             NVARCHAR(45) NULL,
          Storerkey             NVARCHAR(20),
          Consigneekey          NVARCHAR(20) DEFAULT (''), 
          Facility              NVARCHAR(5)  DEFAULT (''),
          CustName              NVARCHAR(50) DEFAULT (''),
          LPExternOrdKey        NVARCHAR(30) DEFAULT (''),
          C_city                NVARCHAR(45) DEFAULT (''),
          PHKey                 NVARCHAR(18) DEFAULT (''),
          LocType               NVARCHAR(30) DEFAULT ('') )
         
      INSERT INTO #temp_picksumm01
      (LoadKey,  c_Company,      Storerkey,       Consigneekey, 
       Facility,  CustName,      LPExternOrdKey,    C_city, PHKey,LocType
      )
   SELECT DISTINCT LoadKey,Company,Storerkey
			,ConsigneeKey,facility,CustName
			,ExternOrderKey,city,PickSlipNo,LocationTypeDesc
	FROM #TEMP_GETPICKSUMM01   
  -- WHERE   ( Loadkey = @c_LoadKey ) 
   WHERE LocationTypeDesc = 'EACH PICKING LIST'
	--GROUP BY ph.pickheaderkey,ord.Storerkey
	--,lp.LoadKey,lp.facility,lpd.ExternOrderKey,
	--lpd.ConsigneeKey,lpd.CustomerName,ord.C_Company,ord.c_city,l.LocationType
	ORDER BY LocationTypeDesc,PickSlipNo DESC
	
	
	 INSERT INTO #temp_picksumm01OTH
      (LoadKey,  c_Company,      Storerkey,       Consigneekey, 
       Facility,  CustName,      LPExternOrdKey,    C_city, PHKey,LocType
      )
   SELECT DISTINCT LoadKey,Company,Storerkey
			,ConsigneeKey,facility,CustName
			,ExternOrderKey,city,PickSlipNo,LocationTypeDesc
	FROM #TEMP_GETPICKSUMM01     
   --WHERE   ( Loadkey = @c_LoadKey ) 
   where LocationTypeDesc = 'PALLET PICKING LIST'
	GROUP BY LoadKey,Company,Storerkey
			,ConsigneeKey,facility,CustName
			,ExternOrderKey,city,PickSlipNo,LocationTypeDesc
	ORDER BY LocationTypeDesc,PickSlipNo DESC
     
     SELECT DISTINCT CASE WHEN ISNULL(T01.LoadKey,'') <> '' THEN T01.LoadKey ELSE OTHT01.LoadKey END AS loadkey,
                   T01.C_Company AS c_company,
                   T01.Storerkey AS storerkey,
                   T01.Consigneekey AS consigneekey, 
                   T01.Facility AS Facility,
                   T01.CustName AS Custname,
			          T01.LPExternOrdKey AS LPExternOrdkey,
			          T01.C_city AS C_city,
			          T01.PHKey AS PHKey,
			          T01.LocType  AS Loctype,
			          OTHT01.C_Company AS OTH_C_company,
						 OTHT01.Consigneekey AS OTH_Consigneekey, 
						 OTHT01.CustName AS OTH_CustName, 
						 OTHT01.LPExternOrdKey AS OTH_LPExternOrdKey, 
						 OTHT01.C_city AS OTH_C_City,
						 OTHT01.PHKey AS OTH_PHKEY 
						,OTHT01.LocType AS OTH_Loctype
   FROM #temp_picksumm01 T01 
   FULL OUTER JOIN #temp_picksumm01OTH OTHT01 ON OTHT01.ID = T01.ID
   --SELECT * FROM #temp_picksumm01OTH
  
   DROP Table #temp_picksumm01
   DROP Table #temp_picksumm01OTH 
	DROP Table #TEMP_GETPICKSUMM01  
	
  END --@n_continue = 1 or 2
  
  END

GO