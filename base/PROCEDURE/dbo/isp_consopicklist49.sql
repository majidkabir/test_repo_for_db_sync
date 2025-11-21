SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_ConsoPickList49                                */
/* Creation Date: 12-APR-2021                                           */
/* Copyright: IDS                                                       */
/* Written by: Modify from nsp_GetPickSlipOrders29                      */
/*                                                                      */
/* Purpose:WMS-16761 [MY]-Consolidated Pickslip print in Wave Module    */
/*                                                                      */
/* Input Parameters:  @c_wavekey  - wavekey                             */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_consolidated_pick49                */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver. Purposes                                  */
/* 02-SEP-2021  CSCHONG  1.1  WMS-17844 revised pickslip logic (CS01)   */
/* 23-OCT-2021  MINGLE   1.2  WMS-18183 add new mappings (ML01)         */
/* 23-OCT-2021  Mingle   1.2  DevOps Combine Script                     */
/************************************************************************/

CREATE PROC [dbo].[isp_ConsoPickList49] (@c_wavekey NVARCHAR(10)) 
 AS
 BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF   
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
  DECLARE
      @n_starttrancnt  int 

    DECLARE @c_pickheaderkey           NVARCHAR(10),
              @c_errmsg                NVARCHAR(255),
              @n_continue              INT,
              @b_success               INT,
              @n_err                   INT,
              @c_PrintedFlag           NVARCHAR(1),
            --@n_pickslips_required    INT                        
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
              @c_NOSPLITBYLINECNTZONE  NVARCHAR(10),
              @c_StorerKey             NVARCHAR(20), 
              @c_GrpByLocZone          NVARCHAR(1) ,
              @c_loadkey               NVARCHAR(20),
              @c_ExecArguments         NVARCHAR(4000)  
        

    SELECT @n_starttrancnt = @@TRANCOUNT, @n_continue = 1


   CREATE TABLE #TEMP_LOADKEYS (  
   Loadkey      NVARCHAR(10) NOT NULL)  
  
   INSERT INTO #TEMP_LOADKEYS  
   SELECT DISTINCT LPD.Loadkey  
   FROM WAVEDETAIL WD (NOLOCK)  
   JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.Orderkey = WD.Orderkey  
   WHERE WD.Wavekey = @c_Wavekey  

    --check if the loadplan already printed other pickslip type then return error to reject.
    IF EXISTS (SELECT PH.PICKHEADERKEY 
               FROM PICKHEADER PH WITH (NOLOCK)
               JOIN #TEMP_LOADKEYS TLP ON TLP.Loadkey = PH.ExternOrderKey
             WHERE  ISNULL(RTRIM(PH.OrderKey),'') = ''
             AND PH.ZONE = 'LP')
    BEGIN
       SELECT @n_continue = 3  
       SELECT @n_err = 63500
       SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Pickslip already printed using Consolidated option. (isp_ConsoPickList49)'
    END
    
      SET @c_StorerKey = ''
      SET @c_GrpByLocZone = 'N'



       SELECT TOP 1 @c_StorerKey = ORD.storerkey
       FROM ORDERS ORD WITH (NOLOCK)
       JOIN #TEMP_LOADKEYS TLP ON TLP.Loadkey = ORD.LoadKey
       --WHERE ORD.Loadkey = @c_loadkey

       SELECT @c_GrpByLocZone = CASE WHEN ISNULL(C.short,'N') = 'Y' THEN C.short ELSE 'N' END
       FROM CODELKUP C WITH (NOLOCK)
       WHERE C.listname = 'REPORTCFG'
       AND C.code = 'GRPBYPICKZONE'
       AND C.long = 'r_dw_consolidated_pick49'
       AND C.storerkey = @c_StorerKey
    
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
         ID               NVARCHAR(18) NULL,       
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
         LRoute           NVARCHAR(10) NULL,                 
         LEXTLoadKey      NVARCHAR(20) NULL,                 
         LPriority        NVARCHAR(10) NULL,                 
         LPuserdefDate01  DATETIME NULL,
         packuom3         NVARCHAR(10) NULL, --ML01
         deliverydate     DATETIME NULL,     --ML01
         notes            NVARCHAR(200) NULL)--ML01                 
      
       INSERT INTO #TEMP_PICK
            (PickSlipNo,          LoadKey,         OrderKey,      ConsigneeKey,
             Company,             Addr1,           Addr2,         Addr3,
             Addr4,               City,            Loc,           ID,
             SKU,                 AltSKU,          SkuDesc,       Qty,
             PrintedFlag,         Locationtypedesc, Lottable01,   Lottable02, Lottable04,
             ExternOrderkey,      LogicalLoc,         Shelflife,  Minshelflife,
             pallet,             casecnt,             pickafterdate,    putawayzone,
             LRoute,LEXTLoadKey,  LPriority,       LPuserdefDate01,  packuom3,
             deliverydate,        notes) --ML01        

        SELECT RefKeyLookup.PickSlipNo,  
           TLP.Loadkey AS Loadkey, --@c_LoadKey as LoadKey,                 
           --PickDetail.OrderKey,                             
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
          -- ISNULL((SELECT Distinct 'Y' FROM PICKHEADER WITH (NOLOCK) WHERE ExternOrderKey = @c_Loadkey AND  Zone = '3'), 'N') AS PrintedFlag, 
           CASE WHEN LOC.Locationtype = 'OTHER' THEN
                'PALLET PICKING LIST'
                ELSE 'EACH PICKING LIST'
           END ,
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
           --CASE WHEN ISNULL(@c_GrpByLocZone,'N') = 'Y' THEN LOC.PickZone ELSE '' END AS Putawayzone,   --CS01
           CASE WHEN ISNULL(@c_GrpByLocZone,'N') = 'Y' THEN LOC.LocationType ELSE '' END AS Putawayzone, --CS01 
           Loadplan.Route AS LRoute,                                                 
           Loadplan.Externloadkey AS LEXTLoadKey,                                     
           Loadplan.Priority AS LPriority,                                           
           Loadplan.LPuserdefDate01  AS LPuserdefDate01,
           PACK.PACKUOM3,       --ML01
           ORDERS.Deliverydate, --ML01
           ORDERS.Notes         --ML01                     
         FROM #TEMP_LOADKEYS TLP
         JOIN LOADPLANDETAIL WITH (NOLOCK) ON LoadPlanDetail.LoadKey = TLP.Loadkey 
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
        --AND LOADPLANDETAIL.LoadKey = @c_LoadKey
        GROUP BY TLP.Loadkey,RefKeyLookup.PickSlipNo,           
           Orders.Orderkey,                         
           --PickDetail.OrderKey,                   
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
           END ,
           LotAttribute.Lottable01,                
           LotAttribute.Lottable02,                
           IsNUll(LotAttribute.Lottable04, '19000101'),        
           ORDERS.ExternOrderKey,
           LOC.LogicalLocation,
           SKU.Shelflife,
           STORER.Minshelflife,
           PACK.Pallet,
           PACK.CaseCnt,
           --CASE WHEN ISNULL(@c_GrpByLocZone,'N') = 'Y' THEN LOC.PickZone ELSE '' END,   --CS01
           CASE WHEN ISNULL(@c_GrpByLocZone,'N') = 'Y' THEN LOC.LocationType ELSE '' END, --CS01
           Loadplan.Route ,                                              
           Loadplan.Externloadkey ,                                        
           Loadplan.Priority ,                                            
           Loadplan.LPuserdefDate01,
           PACK.PACKUOM3,        --ML01
           ORDERS.Deliverydate,  --ML01
           ORDERS.Notes          --ML01 
                                

     BEGIN TRAN  
     -- Uses PickType as a Printed Flag  
     UPDATE PickHeader WITH (ROWLOCK) SET PickType = '1', TrafficCop = NULL 
     WHERE ExternOrderKey IN (SELECT loadkey FROM #TEMP_LOADKEYS ) 
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
      FROM   #TEMP_PICK TP  
      JOIN   ORDERS O (NOLOCK) ON (TP.Orderkey = O.Orderkey) 
      LEFT JOIN CODELKUP CLR (NOLOCK) ON (O.Storerkey = CLR.Storerkey AND CLR.Code = 'NOSPLITBYLINECNTZONE' 
                                          AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_consolidated_pick49' AND ISNULL(CLR.Short,'') <> 'N')
      WHERE  TP.PickSlipNo IS NULL or TP.PickSlipNo = ''  
      ORDER BY TP.LoadKey, TP.OrderKey, TP.LocationTypeDesc,
               TP.Putawayzone, TP.loc, TP.sku, TP.id  

      OPEN C_Orderkey_LocTypeDesc   
     
      FETCH NEXT FROM C_Orderkey_LocTypeDesc INTO @c_LoadKey, @c_OrderKey, @c_LocTypeDesc,
                                                  @c_Putawayzone, @c_sku, @c_loc, @c_id, @c_lottable01, @c_lottable02, @dt_lottable04,    
                                                  @c_NOSPLITBYLINECNTZONE  
     
      WHILE (@@Fetch_Status <> -1)  
      BEGIN -- while 1  
         IF ISNULL(@c_OrderKey, '0') = '0'  
            BREAK  
         
         SELECT @n_Linecount = @n_Linecount + 1  
         
         IF @c_PrevLoadKey <> @c_LoadKey OR   
            @c_PrevOrderKey <> @c_OrderKey --OR                         
           -- @c_PrevLocTypeDesc <> @c_LocTypeDesc --OR                    --CS01
           --(@c_PrevPutawayzone <> @c_Putawayzone AND @c_NOSPLITBYLINECNTZONE <> 'Y') OR  --CS01
            --(@n_Linecount > 15 AND @c_NOSPLITBYLINECNTZONE <> 'Y')
         BEGIN       
--          BEGIN TRAN
            SET @c_PickSlipNo = ''
            SET @n_Linecount = 1                
     
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
                  SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Insert into PICKHEADER Failed. (isp_ConsoPickList49)'
                  GOTO FAILURE
               END             
            END -- @b_success = 1    
            ELSE   
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @n_err = 63502
                SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Get PSNO Failed. (isp_ConsoPickList49)'  
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
                                    'WHERE  OrderDetail.OrderKey =  @c_OrderKey ' +
                                    ' AND    OrderDetail.LoadKey  = @c_LoadKey   ' +
                                    ' AND LOC.PickZone =  CASE WHEN ISNULL(@c_GrpByLocZone,''N'') = ''Y'' THEN RTRIM(@c_Putawayzone) ELSE LOC.PickZone END ' +   
                                    ' AND Pickdetail.Sku =  RTRIM(@c_Sku) ' +   
                                    ' AND Pickdetail.Loc =  RTRIM(@c_Loc) ' +   
                                    ' AND Pickdetail.Id = RTRIM(@c_ID)  ' +   
                                    ' AND Lotattribute.Lottable01 =  RTRIM(@c_Lottable01)  ' +   
                                    ' AND Lotattribute.Lottable02 = RTRIM(@c_Lottable02)  ' +   
                                    ' AND CONVERT(CHAR(10),ISNULL(Lotattribute.Lottable04,''19000101''),112) =  CONVERT(CHAR(10),@dt_Lottable04,112) ' +   
                                    @c_LocTypeCriteria +
                                    ' ORDER BY PickDetail.PickDetailKey '  
   
            --EXEC(@c_ExecStatement)
              SET @c_ExecArguments = N'   @c_OrderKey          NVARCHAR(20)'  
                                     +' , @c_LoadKey           NVARCHAR(10)' 
                                     +' , @c_Sku               NVARCHAR(20)' 
                                     +' , @c_Loc               NVARCHAR(10)' 
                                     +' , @c_ID                NVARCHAR(10)' 
                                     +' , @c_Lottable01        NVARCHAR(18)'
                                     +' , @c_Lottable02        NVARCHAR(18)'
                                     +' , @dt_Lottable04       DATETIME' 
                                     +' , @c_Putawayzone       NVARCHAR(20)' 
                                     +' , @c_GrpByLocZone      NVARCHAR(1)'
              
              
               EXEC sp_ExecuteSql     @c_ExecStatement     
                                    , @c_ExecArguments    
                                    , @c_OrderKey  
                                    , @c_LoadKey  
                                    , @c_Sku 
                                    , @c_Loc
                                    , @c_ID 
                                    , @c_Lottable01 
                                    , @c_Lottable02
                                    , @dt_Lottable04
                                    , @c_Putawayzone
                                    , @c_GrpByLocZone


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
                     SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Insert RefKeyLookup Failed. (isp_ConsoPickList49)'    
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
         AND   Putawayzone = CASE WHEN ISNULL(@c_GrpByLocZone,'N') = 'Y' THEN @c_Putawayzone  ELSE Putawayzone END
         AND   Sku = @c_Sku  
         AND   Loc = @c_Loc  
         AND   ID = @c_ID  
         AND   Lottable01 = @c_Lottable01  
         AND   Lottable02 = @c_Lottable02  
         AND   Lottable04 = @dt_Lottable04  
         AND   (PickSlipNo IS NULL OR PickSlipNo = '')  

         SELECT @n_err = @@ERROR  
         IF @n_err <> 0   
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @n_err = 63504
            SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Update #Temp_Pick Failed. (isp_ConsoPickList49)'    
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
         SET @c_PrevPutawayzone = @c_Putawayzone  
     
         FETCH NEXT FROM C_Orderkey_LocTypeDesc INTO @c_LoadKey, @c_OrderKey, @c_LocTypeDesc,
                                                     @c_Putawayzone, @c_sku, @c_loc, @c_id, @c_lottable01, @c_lottable02, @dt_lottable04,         
                                                     @c_NOSPLITBYLINECNTZONE  

      END -- while 1   
     
      CLOSE C_Orderkey_LocTypeDesc  
      DEALLOCATE C_Orderkey_LocTypeDesc   


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
     SELECT PickSlipNo,          LoadKey,         OrderKey,      ConsigneeKey,
             Company,             Addr1,           Addr2,         Addr3,
             Addr4,               City,            Loc,           ID,
             SKU,                 AltSKU,          SkuDesc,       Qty, PrintedFlag,
             CASE WHEN ISNULL(@c_GrpByLocZone,'N') = 'Y' THEN Locationtypedesc ELSE 'PICKING LIST' END AS Locationtypedesc , 
             Lottable01,   Lottable02, Lottable04,
             ExternOrderkey,      LogicalLoc,         Shelflife,  Minshelflife,
             pallet,             casecnt,             pickafterdate,    putawayzone,
             LRoute,             LEXTLoadKey,      LPriority,     LPuserdefDate01,
             packuom3,           deliverydate,     notes --ML01

     FROM #TEMP_PICK ORDER BY Pickslipno  
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_ConsoPickList49'
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