SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  nsp_GetPickSlipOrders29                        		*/
/* Creation Date: 14-JUL-2009                              			      	*/
/* Copyright: IDS                                                       */
/* Written by: Modify from nsp_GetPickSlipOrders05           			      */
/*                                                                      */
/* Purpose:  Pickslip for Unilever SOS#140956								          	*/
/*                                                                      */
/* Input Parameters:  @c_loadkey  - Loadkey 							            	*/
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_print_pickorder29          			  */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                       						      	*/
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver. Purposes                                  */
/* 23-Nov-2009  NJOW01   1.1  153151 - Add batchno. Lottable02          */ 
/* 03-Jan-2010  NJOW01   1.2  200722 - Add pickzone                     */
/* 31-Mac-2011  AQSKC    1.3  210516 - Unique PSNO for EA and Pallet PS */
/*                            (Kc01)                                    */
/* 07-Jul-2011  njow02   1.4  220069 - Piece loc type break by pickzone */
/* 04-Jan-2013  NJOW03   1.5  262698 - Unique pickslipno on each page   */
/* 25-Sep-2015  CSCHONG  1.6  SOS#352276 (CS01)                         */
/* 27-Mar-2017  NJOW04   1.7  WMS-1445 Configure no split by line count */
/*                            and PA zone                               */   
/* 28-Jan-2019  TLTING_ext 1.8  enlarge externorderkey field length     */
/************************************************************************/

CREATE PROC [dbo].[nsp_GetPickSlipOrders29] (@c_loadkey NVARCHAR(10)) 
 AS
 BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF   
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
  DECLARE
		@n_starttrancnt  int 

    DECLARE @c_pickheaderkey	       NVARCHAR(10),
 		        @c_errmsg			           NVARCHAR(255),
 		        @n_continue              INT,
 		        @b_success		           INT,
 		        @n_err			             INT,
 		        @c_PrintedFlag           NVARCHAR(1),
            --@n_pickslips_required  INT                --(Kc01) 	   	 
            @c_Orderkey              NVARCHAR(10),      --(Kc01)  	   		   
            @c_LocTypeDesc           NVARCHAR(20),      --(Kc01)
            @c_Pickdetailkey         NVARCHAR(10),      --(Kc01)
            @c_PrevLoadkey           NVARCHAR(10),      --(Kc01)
            @c_PrevOrderkey          NVARCHAR(10),      --(KC01)
            @c_PrevLocTypeDesc       NVARCHAR(20),      --(KC01)
            @c_Pickslipno            NVARCHAR(10),      --(Kc01)
            @c_Orderlinenumber       NVARCHAR(5),       --(Kc01)
            @c_LocTypeCriteria       NVARCHAR(255),     --(Kc01)
            @c_ExecStatement         NVARCHAR(4000),     --(Kc01)
            @c_putawayzone           NVARCHAR(10), --NJOW03
            @c_PrevPutawayzone       NVARCHAR(10), --NJOW03
            @n_Linecount             INT, --NJOW03
            @c_sku                   NVARCHAR(20), --NJOW03
            @c_loc                   NVARCHAR(10), --NJOW03
            @c_id                    NVARCHAR(18), --NJOW03
            @c_lottable01            NVARCHAR(18), --NJOW03
            @c_lottable02            NVARCHAR(18), --NJOW03
            @dt_lottable04           DATETIME,     --NJOW03
            @c_NOSPLITBYLINECNTZONE  NVARCHAR(10)  --NJOW04
        

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
    --(Kc01) - end
    
   IF @n_continue = 1 OR @n_continue = 2
	BEGIN
    CREATE TABLE #TEMP_PICK
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
       externorderkey   NVARCHAR(50) NULL,   --tlting_ext
       LogicalLoc       NVARCHAR(18) NULL,
       Shelflife        INT,
       MinShelfLife     INT,
       pallet           INT,
       casecnt          INT,
       pickafterdate    DATETIME NULL,
       putawayzone      NVARCHAR(10) NULL,
       LRoute           NVARCHAR(10) NULL,                --(CS01)
       LEXTLoadKey      NVARCHAR(20) NULL,                --(CS01)
       LPriority        NVARCHAR(10) NULL,                --(CS01)
       LPuserdefDate01  DATETIME NULL)               --(CS01)  
       
       INSERT INTO #TEMP_PICK
            (PickSlipNo,          LoadKey,         OrderKey,		ConsigneeKey,
             Company,             Addr1,           Addr2,			Addr3,
             Addr4,               City,            Loc,           ID,
             SKU,                 AltSKU,          SkuDesc,			Qty,
             PrintedFlag,         Locationtypedesc, Lottable01,	Lottable02, Lottable04,
             ExternOrderkey,      LogicalLoc,	      Shelflife,  Minshelflife,
             pallet,	            casecnt,					pickafterdate,    putawayzone,
             LRoute,LEXTLoadKey,LPriority,LPuserdefDate01)    --(CS01)   
        --(Kc01) - start
        /* 
        SELECT (SELECT PICKHEADERKEY FROM PICKHEADER WITH (NOLOCK)
                WHERE ExternOrderKey = @c_LoadKey 
                AND OrderKey = PickDetail.OrderKey 
                AND ZONE = '3'),
        */
        SELECT RefKeyLookup.PickSlipNo,  
        --(Kc01) - end
           @c_LoadKey as LoadKey,                 
           --PickDetail.OrderKey,                            --(Kc01)
           ORDERS.OrderKey,                                  --(Kc01)
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
                     AND Orderkey = ORDERS.Orderkey AND  Zone = 'LP') , 'N') AS PrintedFlag,           --(Kc01)
          -- ISNULL((SELECT Distinct 'Y' FROM PICKHEADER WITH (NOLOCK) WHERE ExternOrderKey = @c_Loadkey AND  Zone = '3'), 'N') AS PrintedFlag, 
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
           Loadplan.Route AS LRoute,                                                --(CS01)
           Loadplan.Externloadkey AS LEXTLoadKey,                                   --(CS01) 
           Loadplan.Priority AS LPriority,                                          --(CS01)
           Loadplan.LPuserdefDate01  AS LPuserdefDate01                             --(CS01)  
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
        LEFT OUTER JOIN RefKeyLookup (NOLOCK) ON (RefKeyLookup.PickDetailKey = PICKDETAIL.PickDetailKey)      --(KC01)
        JOIN LOADPLAN WITH (NOLOCK) ON LOADPLAN.loadkey = ORDERDETAIL.loadkey    --(CS01)
        WHERE PICKDETAIL.Status < '5'  
        AND LOADPLANDETAIL.LoadKey = @c_LoadKey
        GROUP BY RefKeyLookup.PickSlipNo,          --(Kc01)
           Orders.Orderkey,                        --(Kc01)
           --PickDetail.OrderKey,                  --(Kc01)
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
           Loadplan.Route ,                                             --(CS01)
           Loadplan.Externloadkey ,                                      --(CS01) 
           Loadplan.Priority ,                                           --(CS01)
           Loadplan.LPuserdefDate01                                      --(CS01)   

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
--(Kc01) - start
/*      
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
         INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)
             SELECT 'P' + RIGHT ( REPLICATE ('0', 9) + 
             dbo.fnc_LTrim( dbo.fnc_RTrim(
                STR( 
                   CAST(@c_pickheaderkey AS int) + ( select count(distinct orderkey) 
                          from #TEMP_PICK as Rank 
                          WHERE Rank.OrderKey < #TEMP_PICK.OrderKey ) 
                    ) -- str
                    )) -- rtrim
                 , 9) 
              , OrderKey, LoadKey, '0', '3', ''
             FROM #TEMP_PICK WHERE PickSlipNo IS NULL
             GROUP By LoadKey, OrderKey
             
         UPDATE #TEMP_PICK 
         SET PickSlipNo = PICKHEADER.PickHeaderKey
         FROM PICKHEADER WITH (NOLOCK)
         WHERE PICKHEADER.ExternOrderKey = #TEMP_PICK.LoadKey
         AND   PICKHEADER.OrderKey = #TEMP_PICK.OrderKey
         AND   PICKHEADER.Zone = '3'
			   AND   #TEMP_PICK.PickSlipNo IS NULL
     END
*/
      SET @c_LoadKey = ''  
      SET @c_OrderKey = ''  
      SET @c_LocTypeDesc = ''
      SET @c_PickDetailKey = ''  
      SET @n_Continue = 1   
      SET @c_Putawayzone = '' --NJOW03
      SET @n_Linecount = 0 --NJOW03
     
      DECLARE C_Orderkey_LocTypeDesc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
      SELECT DISTINCT TP.LoadKey, TP.OrderKey, TP.LocationTypeDesc,
             TP.Putawayzone, TP.sku, TP.loc, TP.id, TP.lottable01, TP.lottable02, TP.lottable04, --NJOW03   
             CASE WHEN CLR.Code IS NOT NULL THEN 'Y' ELSE 'N' END AS NOSPLITBYLINECNTZONE --NJOW04
      FROM   #TEMP_PICK TP  
      JOIN   ORDERS O (NOLOCK) ON (TP.Orderkey = O.Orderkey) --NJOW04
      LEFT JOIN CODELKUP CLR (NOLOCK) ON (O.Storerkey = CLR.Storerkey AND CLR.Code = 'NOSPLITBYLINECNTZONE' 
                                          AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_print_pickorder29' AND ISNULL(CLR.Short,'') <> 'N') --NJOW04
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
		            SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Insert into PICKHEADER Failed. (nsp_GetPickSlipOrders29)'
                  GOTO FAILURE
               END             
            END -- @b_success = 1    
            ELSE   
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @n_err = 63502
	             SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Get PSNO Failed. (nsp_GetPickSlipOrders29)'  
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
                                    'JOIN   LOTATTRIBUTE WITH (NOLOCK) ON (PICKDETAIL.Lot = LOTATTRIBUTE.Lot) ' +  --NJOW03
                                    'WHERE  OrderDetail.OrderKey = N''' + @c_OrderKey + '''' +
                                    ' AND    OrderDetail.LoadKey  = N''' + @c_LoadKey  + ''' ' +
                                    ' AND LOC.PickZone = N''' + RTRIM(@c_Putawayzone) + ''' ' +  --NJOW03
                                    ' AND Pickdetail.Sku = N''' + RTRIM(@c_Sku) + ''' ' +  --NJOW03
                                    ' AND Pickdetail.Loc = N''' + RTRIM(@c_Loc) + ''' ' +  --NJOW03
                                    ' AND Pickdetail.Id = N''' + RTRIM(@c_ID) + ''' ' +  --NJOW03
                                    ' AND Lotattribute.Lottable01 = N''' + RTRIM(@c_Lottable01) + ''' ' +  --NJOW03
                                    ' AND Lotattribute.Lottable02 = N''' + RTRIM(@c_Lottable02) + ''' ' +  --NJOW03
                                    ' AND CONVERT(CHAR(10),ISNULL(Lotattribute.Lottable04,''19000101''),112) = ''' + CONVERT(CHAR(10),@dt_Lottable04,112) + ''' ' +  --NJOW03
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
	                  SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Insert RefKeyLookup Failed. (nsp_GetPickSlipOrders29)'    
                     GOTO FAILURE
                  END                          
               END   
     
               FETCH NEXT FROM C_PickDetailKey INTO @c_PickDetailKey, @c_OrderLineNumber   
            END   
            CLOSE C_PickDetailKey   
            DEALLOCATE C_PickDetailKey        
         END   
                
         UPDATE #TEMP_PICK  
         SET PickSlipNo = @c_PickSlipNo  
         WHERE OrderKey = @c_OrderKey  
         AND   LoadKey = @c_LoadKey         
         AND   LocationTypeDesc = @c_LocTypeDesc
         AND   Putawayzone = @c_Putawayzone --NJOW03
         AND   Sku = @c_Sku --NJOW03
         AND   Loc = @c_Loc --NJOW03
         AND   ID = @c_ID --NJOW03
         AND   Lottable01 = @c_Lottable01 --NJOW03
         AND   Lottable02 = @c_Lottable02 --NJOW03
         AND   Lottable04 = @dt_Lottable04 --NJOW03
         AND   (PickSlipNo IS NULL OR PickSlipNo = '')  

         SELECT @n_err = @@ERROR  
         IF @n_err <> 0   
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @n_err = 63504
            SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Update #Temp_Pick Failed. (nsp_GetPickSlipOrders29)'    
            GOTO FAILURE
         END  
--         ELSE
--         BEGIN
--            WHILE @@TRANCOUNT > 0
--            COMMIT TRAN
--         END

         SET @c_PrevLoadKey = @c_LoadKey   
         SET @c_PrevOrderKey = @c_OrderKey 
         SET @c_PrevLocTypeDesc = @c_LocTypeDesc 
         SET @c_PrevPutawayzone = @c_Putawayzone --NJOW03
     
         FETCH NEXT FROM C_Orderkey_LocTypeDesc INTO @c_LoadKey, @c_OrderKey, @c_LocTypeDesc,
                                                     @c_Putawayzone, @c_sku, @c_loc, @c_id, @c_lottable01, @c_lottable02, @dt_lottable04, --NJOW03       
                                                     @c_NOSPLITBYLINECNTZONE --NJOW04

      END -- while 1   
     
      CLOSE C_Orderkey_LocTypeDesc  
      DEALLOCATE C_Orderkey_LocTypeDesc   

--(Kc01) - end
     GOTO SUCCESS
 FAILURE:
     DELETE FROM #TEMP_PICK
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
     SELECT * FROM #TEMP_PICK ORDER BY Pickslipno  
	   DROP Table #TEMP_PICK  
  END --@n_continue = 1 or 2

	IF @n_continue=3  -- Error Occured - Process And Return
	BEGIN
		SELECT @b_success = 0
		IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTranCnt
		BEGIN
			ROLLBACK TRAN
		END
		ELSE
		BEGIN
			WHILE @@TRANCOUNT > @n_StartTranCnt
			BEGIN
				COMMIT TRAN
			END
		END
		EXECUTE nsp_logerror @n_err, @c_errmsg, 'nsp_GetPickSlipOrders29'
		RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
		RETURN
	END
	ELSE
	BEGIN
		SELECT @b_success = 1
		WHILE @@TRANCOUNT > @n_StartTranCnt
		BEGIN
			COMMIT TRAN
		END
		RETURN
	END

 END

GO