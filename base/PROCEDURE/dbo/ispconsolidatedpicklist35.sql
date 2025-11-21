SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispConsolidatedPickList35                          */
/* Creation Date:                                                       */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  315650 - PH - GSK Consolidated Picklist (Load Plan)        */
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
/* Date         Author   Ver.  Purposes                                 */
/* 07/11/2014   NJOW01   1.0   315650-Change order.route to             */
/*                             loadplan.route                           */
/* 18-Sep-2015 CSCHONG   1.1   SOS#352276 (CS01)                        */
/* 28-Jan-2019 TLTING_ext 1.2  enlarge externorderkey field length     */
/************************************************************************/

CREATE PROC [dbo].[ispConsolidatedPickList35](@c_LoadKey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nStartTranCount int  
  
   SET @nStartTranCount = @@TRANCOUNT   
  	
   DECLARE @n_err             INT,
           @n_continue        INT,
           @b_success         INT,
           @c_errmsg          NVARCHAR(255),
           @n_Count           INT,           
           @n_GroupNo         INT,
           @n_GroupSeq        INT,
           @n_GroupNoFound    INT,
           @n_GroupSeqFound   INT

   DECLARE @c_sku	          NVARCHAR(20),
           @c_storerkey       NVARCHAR(15),
           @c_Route           NVARCHAR(10),
           @n_Qty             INT,
           @c_Pack            NVARCHAR(10),
           @n_CaseCnt         INT,
           @n_Pallet          INT,
           @n_PalletQty       INT,
           @n_CaseQty         INT,
           @n_LooseQty        INT,
           @c_UOM1            NVARCHAR(10),
           @C_UOM3            NVARCHAR(10),
           @C_UOM4            NVARCHAR(10),                      
           @c_PickDetailKey   NVARCHAR(10),
           @c_CurrLoadkey     NVARCHAR(10),
           @c_PrevLoadkey     NVARCHAR(10),
           @c_PickType        NVARCHAR(10),           
           @c_PrevRoute       NVARCHAR(10),
           @c_Lot             NVARCHAR(10),
           @c_ID              NVARCHAR(18),
           @c_Facility        NVARCHAR(5),
           @c_FacDescr        NVARCHAR(50),
           @c_Company         NVARCHAR(45),           
           @c_PickSlipNo      NVARCHAR(18),
           @c_lottable01      NVARCHAR(18),
           @c_lottable02      NVARCHAR(18),
           @c_lottable03      NVARCHAR(18),
           @d_lottable04      DATETIME,
           @c_OrderKey        NVARCHAR(10),
           @c_OrderLineNumber NVARCHAR(5),
           @c_ExternOrderkey  NVARCHAR(50),  --tlting_ext
           @c_LOC             NVARCHAR(10),
           @n_PrevGroupNo     INT,
           @c_logicallocation NVARCHAR(18),
           @c_SkuDescr        NVARCHAR(60),
           @c_LEXTLoadKey     NVARCHAR(20),   --(CS01)
           @c_LPriority       NVARCHAR(10),   --(CS01)
           @c_LPuserdefDate01 DATETIME   --(CS01)

   DECLARE @c_OrderKey1  NVARCHAR(10),
           @c_OrderKey2  NVARCHAR(10),
           @c_OrderKey3  NVARCHAR(10),
           @c_OrderKey4  NVARCHAR(10),
           @c_OrderKey5  NVARCHAR(10),
           @c_OrderKey6  NVARCHAR(10),
           @c_OrderKey7  NVARCHAR(10),
           @c_OrderKey8  NVARCHAR(10)
           
   DECLARE @c_ExternOrderkey1 NVARCHAR(50),    --Tlting_ext
           @c_ExternOrderkey2 NVARCHAR(50),    --Tlting_ext
           @c_ExternOrderkey3 NVARCHAR(50),    --Tlting_ext
           @c_ExternOrderkey4 NVARCHAR(50),    --Tlting_ext
           @c_ExternOrderkey5 NVARCHAR(50),    --Tlting_ext
           @c_ExternOrderkey6 NVARCHAR(50),    --Tlting_ext
           @c_ExternOrderkey7 NVARCHAR(50),    --Tlting_ext
           @c_ExternOrderkey8 NVARCHAR(50)     --Tlting_ext
              
   DECLARE @n_Qty1   int,
           @c_Pack1  NVARCHAR(10),
           @n_Qty2   int,
           @c_Pack2  NVARCHAR(10),
           @n_Qty3   int,
           @c_Pack3  NVARCHAR(10),
           @n_Qty4   int,
           @c_Pack4  NVARCHAR(10),
           @n_Qty5   int,
           @c_Pack5  NVARCHAR(10),
           @n_Qty6   int,
           @c_Pack6  NVARCHAR(10),
           @n_Qty7   int,
           @c_Pack7  NVARCHAR(10),
           @n_Qty8   int,
           @c_Pack8  NVARCHAR(10)
              
   SELECT @n_continue = 1
               
   /*Create Temp Result table */
   
   CREATE TABLE #CONSOLIDATED      
               (ConsoGroupNo INT     NULL,
                LoadKey NVARCHAR(10) NULL,
                Route NVARCHAR(10)   NULL, 
                Storerkey NVARCHAR(15) NULL,
                Facility NVARCHAR(15)  NULL,         
                Loc NVARCHAR(10) NULL,
                ID NVARCHAR(18)  NULL,
                SKU NVARCHAR(20) NULL,
                OrderKey1 NVARCHAR(10) NULL,
                OrderKey2 NVARCHAR(10) NULL,
                OrderKey3 NVARCHAR(10) NULL,
                OrderKey4 NVARCHAR(10) NULL,
                OrderKey5 NVARCHAR(10) NULL,
                OrderKey6 NVARCHAR(10) NULL,
                OrderKey7 NVARCHAR(10) NULL,
                OrderKey8 NVARCHAR(10) NULL,
                Qty1 INT NULL,
                Qty2 INT NULL,
                Qty3 INT NULL,
                Qty4 INT NULL,
                Qty5 INT NULL,
                Qty6 INT NULL,
                Qty7 INT NULL,
                Qty8 INT NULL,
                Pack1 NVARCHAR(10) NULL,
                Pack2 NVARCHAR(10) NULL,
                Pack3 NVARCHAR(10) NULL,
                Pack4 NVARCHAR(10) NULL,
                Pack5 NVARCHAR(10) NULL,
                Pack6 NVARCHAR(10) NULL,
                Pack7 NVARCHAR(10) NULL,
                Pack8 NVARCHAR(10) NULL,
                SkuDescr NVARCHAR(60) NULL,
                FacDescr NVARCHAR(50) NULL,
                Company NVARCHAR(45)  NULL,
                UOM1 NVARCHAR(10) NULL,
                UOM3 NVARCHAR(10) NULL,
                CaseCnt INT NULL,
                Pallet INT  NULL,
                ExternOrderKey1 NVARCHAR(50) NULL,           -- tlting_ext
                ExternOrderKey2 NVARCHAR(50) NULL,           -- tlting_ext
                ExternOrderKey3 NVARCHAR(50) NULL,           -- tlting_ext
                ExternOrderKey4 NVARCHAR(50) NULL,           -- tlting_ext
                ExternOrderKey5 NVARCHAR(50) NULL,           -- tlting_ext
                ExternOrderKey6 NVARCHAR(50) NULL,           -- tlting_ext
                ExternOrderKey7 NVARCHAR(50) NULL,           -- tlting_ext
                ExternOrderKey8 NVARCHAR(50) NULL,           -- tlting_ext
                PickSlipNo NVARCHAR(18) NULL,
                Lottable01 NVARCHAR(18) NULL,
                Lottable02 NVARCHAR(18) NULL,
                Lottable03 NVARCHAR(18) NULL,
                Lottable04 DATETIME   NULL,
                PickType   NVARCHAR(10) NULL,
                LEXTLoadKey NVARCHAR(20) NULL,                    --(CS01)
                LPriority   NVARCHAR(10) NULL,                    --(CS01)
                LPuserdefDate01 DATETIME NULL)                --(CS01)
/*          
   SELECT ConsoGroupNo = 0,
          Loadplan.LoadKey LoadKey,
          LoadPlan.Route Route, --NJOW01
          ORDERS.Storerkey Storerkey,
          ORDERS.Facility Facility,         
          PICKDETAIL.LOC Loc,
          PICKDETAIL.ID ID,
          PICKDETAIL.SKU SKU,
          ORDERS.OrderKey  OrderKey1,
          ORDERS.OrderKey  OrderKey2,
          ORDERS.OrderKey  OrderKey3,
          ORDERS.OrderKey  OrderKey4,
          ORDERS.OrderKey  OrderKey5,
          ORDERS.OrderKey  OrderKey6,
          ORDERS.OrderKey  OrderKey7,
          ORDERS.OrderKey  OrderKey8,
          PICKDETAIL.QTY   Qty1,
          PICKDETAIL.QTY   Qty2,
          PICKDETAIL.QTY   Qty3,
          PICKDETAIL.QTY   Qty4,
          PICKDETAIL.QTY   Qty5,
          PICKDETAIL.QTY   Qty6,
          PICKDETAIL.QTY   Qty7,
          PICKDETAIL.QTY   Qty8,
          Pack1=Space(10),
          Pack2=Space(10),
          Pack3=Space(10),
          Pack4=Space(10),
          Pack5=Space(10),
          Pack6=Space(10),
          Pack7=Space(10),
          Pack8=Space(10),
          SkuDescr=Space(60),
          FacDescr=Space(50),
          Company=Space(45),
          UOM1=Space(10),
          UOM3=Space(10),
          CaseCnt=0,
          Pallet=0,
          ORDERS.ExternOrderKey ExternOrderKey1,
          ORDERS.ExternOrderKey ExternOrderKey2,
          ORDERS.ExternOrderKey ExternOrderKey3,
          ORDERS.ExternOrderKey ExternOrderKey4,
          ORDERS.ExternOrderKey ExternOrderKey5,
          ORDERS.ExternOrderKey ExternOrderKey6,
          ORDERS.ExternOrderKey ExternOrderKey7,
          ORDERS.ExternOrderKey ExternOrderKey8,
          PickSlipNo=Space(18),
          Lottable01=Space(18),
          Lottable02=Space(18),
          Lottable03=Space(18),
          Lottable04=GetDate(),
          PickType=Space(10)
   INTO #CONSOLIDATED
   FROM LOADPLAN (NOLOCK), ORDERS (NOLOCK), PICKDETAIL (NOLOCK)
   WHERE 1 = 2
*/   
         
   SELECT LOC=space(10),
          SKU.SKU SKU,
          ORDERS.OrderKey OrderKey,
          GroupNo=0,
          GroupSeq=0,
          Lot=space(10),
          ID=space(18)
   INTO #SKUGroup
   FROM SKU, ORDERS
   WHERE 1 = 2

   SELECT RefKeyLookup.PickSlipNo,                                                                  
          ORDERS.Externorderkey,  
          ORDERS.Orderkey,  
          LOADPLAN.Route, --NJOW01
          ORDERS.Storerkey,
          ORDERS.Facility,
          FACILITY.Descr AS FacDescr,
          STORER.Company,
          LOADPLAN.Loadkey,  
          PICKDETAIL.Loc,  
          PICKDETAIL.ID,
          PICKDETAIL.Lot,           
          PICKDETAIL.Qty,  
          ORDERDETAIL.OrderLineNumber,
          ORDERDETAIL.Sku,  
          SKU.Descr AS SkuDescr,
          ISNULL((SELECT Distinct 'Y' FROM PickHeader WITH (NOLOCK) WHERE PickHeaderkey = RefKeyLookup.PickSlipNo
                  AND  Zone = 'LP') , 'N') AS PrintedFlag,  
          LOC.Logicallocation,  
          LOTATTRIBUTE.Lottable01,
          LOTATTRIBUTE.Lottable02,
          LOTATTRIBUTE.Lottable03,
          LOTATTRIBUTE.Lottable04,
          PACK.Casecnt,
          PACK.Pallet,
          CASE WHEN PACK.Pallet = PICKDETAIL.Qty THEN 'PALLET' ELSE 'CASE/PIECE' END AS PickType,
          PICKDETAIL.Pickdetailkey,
          PACK.PackUOM1,
          PACK.PackUOM3,
          PACK.PackUOM4,
          Loadplan.Externloadkey AS LEXTLoadKey,                                   --(CS01) 
          Loadplan.Priority AS LPriority,                                          --(CS01)
          Loadplan.LPuserdefDate01 AS LPuserdefDate01    --(CS01)
   INTO #TEMP_PICK             
   FROM LOADPLAN (NOLOCK)   
   JOIN LOADPLANDETAIL (NOLOCK) ON (LOADPLAN.Loadkey = LOADPLANDETAIL.Loadkey)  
   JOIN ORDERS (NOLOCK) ON (LOADPLANDETAIL.Orderkey = ORDERS.Orderkey)  
   JOIN ORDERDETAIL (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)  
   JOIN FACILITY (NOLOCK) ON (ORDERS.Facility = FACILITY.Facility)  
   JOIN STORER (NOLOCK) ON (ORDERS.Storerkey = STORER.Storerkey)  
   JOIN SKU (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey   
                         AND ORDERDETAIL.Sku = SKU.Sku)   
   JOIN PACK (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
   JOIN PICKDETAIL (NOLOCK) ON (ORDERDETAIL.Orderkey = PICKDETAIL.Orderkey   
                                AND ORDERDETAIL.Orderlinenumber = PICKDETAIL.Orderlinenumber)  
   JOIN LOC (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc)  
   JOIN LOTATTRIBUTE (NOLOCK) ON (PICKDETAIL.Lot = LOTATTRIBUTE.Lot)
   LEFT OUTER JOIN RefKeyLookup (NOLOCK) ON (RefKeyLookup.PickDetailKey = PICKDETAIL.PickDetailKey)
   WHERE LOADPLAN.Loadkey = @c_loadkey  
   
  BEGIN TRAN    
  
  -- Uses PickType as a Printed Flag    
  UPDATE PickHeader WITH (ROWLOCK)
  SET PickType = '1'
     ,TrafficCop = NULL   
  FROM   PickHeader
  JOIN   #TEMP_PICK ON (PickHeader.ExternOrderkey = #TEMP_PICK.Loadkey)
  WHERE  PickHeader.Zone = 'LP'
  AND PickHeader.Wavekey IN ('PALLET','CASE/PIECE')
--  AND PickHeader.ExternOrderKey = @c_LoadKey
  
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
  
   DECLARE C_LoadKey_ExternOrdKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
   SELECT DISTINCT LoadKey, PickType
   FROM   #TEMP_PICK   
   WHERE  ISNULL(PickSlipNo,'') = ''
   ORDER BY LoadKey, Picktype

   OPEN C_LoadKey_ExternOrdKey   
  
   FETCH NEXT FROM C_LoadKey_ExternOrdKey INTO @c_CurrLoadKey, @c_PickType
  
   WHILE (@@Fetch_Status <> -1)  
   BEGIN -- while 1  
   	  SET @c_Pickslipno = ''
   	  
      SELECT TOP 1 @c_PickSlipNo = PickHeaderKey
      FROM PICKHEADER (NOLOCK)
      WHERE ExternOrderkey = @c_CurrLoadkey
      AND Wavekey = @c_PickType
      AND Zone = 'LP'
  
      IF ISNULL(@c_PickSlipNo,'') = ''
      BEGIN       
         SET @c_PickSlipNo = ''  
    
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

            INSERT PICKHEADER (pickheaderkey, ExternOrderkey, zone, PickType,   Wavekey)  
                       VALUES (@c_PickSlipNo, @c_CurrLoadkey, 'LP', '0',  @c_PickType)  

            IF @@ERROR <> 0   
            BEGIN  
               SET @n_Continue = 3   
               BREAK   
            END   
         END -- @b_success = 1    
         ELSE   
         BEGIN  
            BREAK   
         END   
      END 
  
      IF @n_Continue = 1   
      BEGIN  
         DECLARE C_PickDetailKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT PickDetailKey, 
                OrderKey,
                OrderLineNumber    
         FROM   #TEMP_PICK 
         WHERE  LoadKey   = @c_CurrLoadKey  
         AND    PickType = @c_PickType
         ORDER BY PickDetailKey   
      
         OPEN C_PickDetailKey  
      
         FETCH NEXT FROM C_PickDetailKey INTO @c_PickDetailKey, @c_Orderkey, @c_OrderLineNumber   
      
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  
            IF NOT EXISTS (SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @c_PickDetailKey)   
            BEGIN   
               INSERT INTO RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey)  
               VALUES (@c_PickDetailKey, @c_PickSlipNo, @c_OrderKey, @c_OrderLineNumber, @c_CurrLoadKey)                          
            END   
      
            FETCH NEXT FROM C_PickDetailKey INTO @c_PickDetailKey, @c_Orderkey, @c_OrderLineNumber   
         END   
         CLOSE C_PickDetailKey   
         DEALLOCATE C_PickDetailKey   
      END           

      UPDATE #TEMP_PICK  
      SET PickSlipNo = @c_PickSlipNo  
      WHERE LoadKey = @c_CurrLoadKey         
      AND   PickType = @c_PickType
      AND   ISNULL(PickSlipNo,'') = ''
  
      FETCH NEXT FROM C_LoadKey_ExternOrdKey INTO @c_CurrLoadKey, @c_PickType
   END -- while 1   
  
   CLOSE C_LoadKey_ExternOrdKey  
   DEALLOCATE C_LoadKey_ExternOrdKey   

      -- Do a grouping for sku      
      DECLARE CUR_1 SCROLL CURSOR FOR
         SELECT DISTINCT Orderkey,
                SKU, 
                LOC,
                LogicalLocation,
                Lot,
                ISNULL(Loadkey,''),
                ISNULL(Route,''),
                ID
         FROM #TEMP_PICK
         ORDER BY ISNULL(Loadkey,''), ISNULL(Route,''), Orderkey                         
         
      OPEN CUR_1
      SELECT @n_GroupNo = 1, @n_GroupSeq = 0
      SELECT @c_PrevLoadkey = '', @c_PrevRoute = ''
      
      FETCH NEXT FROM CUR_1 INTO @c_OrderKey, @c_SKU, @c_Loc, @c_logicallocation, @c_lot, @c_CurrLoadKey, @c_Route, @c_ID
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SELECT @n_Count = Count(*)
         FROM   #SKUGroup
         WHERE  OrderKey = @c_OrderKey

         IF @n_Count = 0 
         BEGIN
            SELECT @n_GroupSeq = @n_GroupSeq + 1
            IF @n_GroupSeq > 8 OR @c_CurrLoadkey <> @c_PrevLoadkey OR @c_Route <> @c_PrevRoute 
            BEGIN
               SELECT @n_GroupNo=@n_GroupNo + 1
               SELECT @n_GroupSeq = 1
            END
            
            INSERT INTO #SKUGroup VALUES (@c_LOC,
                   @c_SKU,
                   @c_OrderKey,
                   IsNULL(@n_GroupNo,  1) ,
                   IsNULL(@n_GroupSeq, 1),
                   @c_lot,
                   @c_ID)
         END -- IF ORDERKEY NOT EXIST
         ELSE
         BEGIN
            SELECT @n_GroupNoFound = GroupNo,
                   @n_GroupSeqFound = GroupSeq
            FROM   #SKUGroup
            WHERE  OrderKey = @c_OrderKey
            
            INSERT INTO #SKUGroup VALUES (@c_LOC,
                   @c_SKU,
                   @c_OrderKey,
                   IsNULL(@n_GroupNoFound,  1) ,
                   IsNULL(@n_GroupSeqFound, 1),
                   @c_lot,
                   @c_ID)
         END
         
         SELECT @c_PrevLoadkey = @c_CurrLoadKey
         SELECT @c_PrevRoute = @c_Route
         
         FETCH NEXT FROM CUR_1 INTO @c_OrderKey, @c_SKU, @c_Loc, @c_logicallocation, @c_lot, @c_CurrLoadKey, @c_Route, @c_ID
      END -- WHILE FETCH STATUS <> -1

      CLOSE CUR_1
      DEALLOCATE CUR_1
      
      SET @n_PrevGroupNo = 0
            
      -- 1 groupno = 1 load = 1 route = 2 picktype = multiple lot, loc, id, orders = 1 faciliy = 1 storer
      DECLARE CUR_2 SCROLL CURSOR FOR    
      SELECT DISTINCT SG.LOC, SG.SKU, SG.LOT, SG.ID, SG.GroupNo, TP.PickType, 
                      TP.Loadkey, TP.Route, TP.Storerkey, TP.CaseCnt, TP.Pallet,
                      TP.Lottable01, TP.Lottable02, TP.Lottable03, TP.Lottable04,
                      TP.PackUOM1, TP.PackUOM3, TP.PackUOM4, TP.SkuDescr,
                      TP.Facility, TP.FacDescr, TP.Company, TP.Pickslipno,
                      TP.LEXTLoadKey,TP.LPriority,TP.LPuserdefDate01         --(CS01)
      FROM #SKUGroup SG
      JOIN #TEMP_PICK TP ON (SG.Orderkey = TP.Orderkey AND SG.Sku = TP.Sku AND SG.Lot = TP.Lot
                             AND SG.Loc = TP.Loc AND SG.ID = TP.ID)
      ORDER BY SG.GroupNo, TP.PickType, SG.LOC, SG.SKU, SG.Lot, SG.ID
      
      OPEN CUR_2
      
      FETCH NEXT FROM CUR_2 INTO @c_LOC, @c_SKU, @c_lot, @c_ID, @n_GroupNo, @c_PickType,
                                 @c_CurrLoadkey, @c_Route, @c_Storerkey, @n_CaseCnt, @n_Pallet,
                                 @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04,
                                 @c_UOM1, @c_UOM3, @c_UOM4, @c_SkuDescr,
                                 @c_Facility, @c_FacDescr, @c_Company, @c_PickSlipno,
                                 @c_LEXTLoadKey,@c_LPriority,@c_LPuserdefDate01          --(CS01)
      WHILE @@FETCH_STATUS <> -1
      BEGIN
      	
      	 IF @n_PrevGroupno <>  @n_GroupNo
   	     BEGIN
            SELECT @c_ExternOrderkey1='', @c_ExternOrderkey2='', @c_ExternOrderkey3='', @c_ExternOrderkey4='', @c_ExternOrderkey5='', @c_ExternOrderkey6='', @c_ExternOrderkey7='', @c_ExternOrderkey8=''  
            SELECT @c_orderkey1='', @c_orderkey2='', @c_orderkey3='', @c_orderkey4='', @c_orderkey5='', @c_orderkey6='', @c_orderkey7='', @c_orderkey8=''  
   	     END

         DECLARE CUR_3 CURSOR FOR
            SELECT SG.ORDERKEY, TP.ExternOrderkey, SG.GroupSeq, 
                 SUM(TP.Qty) AS Qty,
                 SUM(CASE WHEN TP.CaseCnt > 0 THEN FLOOR(TP.Qty / TP.CaseCnt) ELSE 0 END) AS CaseQty,
                 SUM(CASE WHEN TP.CaseCnt > 0 THEN TP.Qty % CAST(TP.CaseCnt AS INT) ELSE TP.Qty END) AS LooseQty,                 
                 SUM(CASE WHEN TP.Pallet > 0 THEN FLOOR(TP.Qty / TP.Pallet) ELSE 0 END) AS PalletQty
            FROM #SKUGroup SG
            JOIN #TEMP_PICK TP ON (SG.Orderkey = TP.Orderkey AND SG.Sku = TP.Sku AND SG.Lot = TP.Lot
                             AND SG.Loc = TP.Loc AND SG.ID = TP.ID)
            WHERE  SG.LOC = @c_LOC
            AND    SG.Lot = @c_lot
            AND    SG.SKU = @c_SKU
            AND    SG.ID  = @c_ID
            AND    SG.GroupNo = @n_GroupNo
            AND    TP.PickType = @c_PickType
            AND    TP.Loadkey = @c_CurrLoadkey
            AND    TP.Route = @c_Route
            AND    TP.Storerkey = @c_Storerkey
            GROUP BY SG.Orderkey,  TP.ExternOrderkey, SG.GroupSeq
            ORDER BY SG.GroupSeq       
         
         OPEN CUR_3
         FETCH NEXT FROM CUR_3 INTO @c_OrderKey, @c_ExternOrderkey, @n_GroupSeq, @n_Qty, @n_CaseQty, @n_LooseQty, @n_PalletQty

         SELECT @n_Qty1=0, @n_Qty2=0, @n_Qty3=0, @n_Qty4=0, @n_Qty5=0, @n_Qty6=0, @n_Qty7=0, @n_Qty8=0  
         SELECT @c_Pack1='', @c_Pack2='', @c_Pack3='', @c_Pack4='', @c_Pack5='', @c_Pack6='', @c_Pack7='', @c_Pack8=''  
         
         WHILE @@FETCH_STATUS <> -1
         BEGIN
         	            
            IF @c_PickType = 'PALLET' 
            BEGIN            	
               SELECT @c_Pack = CONVERT(NVARCHAR(10),@n_PalletQty)
               SELECT @c_UOM1 = @c_UOM4
               SELECT @n_LooseQty = 0
            END
            ELSE
            BEGIN
               SELECT @c_Pack = CONVERT(NVARCHAR(10),@n_CaseQty)
            END
            
            IF @n_GroupSeq = 1
            BEGIN
               SELECT @c_ExternOrderkey1 = @c_ExternOrderkey
               SELECT @c_OrderKey1 = @c_OrderKey
               SELECT @n_Qty1      = @n_LooseQty
               SELECT @c_Pack1     = @c_Pack
            END
            ELSE IF @n_GroupSeq = 2
            BEGIN
               SELECT @c_ExternOrderkey2 = @c_ExternOrderkey
               SELECT @c_OrderKey2 = @c_OrderKey
               SELECT @n_Qty2      = @n_LooseQty
               SELECT @c_Pack2     = @c_Pack
            END
            ELSE IF @n_GroupSeq = 3
            BEGIN
               SELECT @c_ExternOrderkey3 = @c_ExternOrderkey
               SELECT @c_OrderKey3 = @c_OrderKey
               SELECT @n_Qty3      = @n_LooseQty
               SELECT @c_Pack3     = @c_Pack
            END
            ELSE IF @n_GroupSeq = 4
            BEGIN
               SELECT @c_ExternOrderkey4 = @c_ExternOrderkey
               SELECT @c_OrderKey4 = @c_OrderKey
               SELECT @n_Qty4      = @n_LooseQty
               SELECT @c_Pack4     = @c_Pack
            END
            ELSE IF @n_GroupSeq = 5
            BEGIN
               SELECT @c_ExternOrderkey5 = @c_ExternOrderkey
               SELECT @c_OrderKey5 = @c_OrderKey
               SELECT @n_Qty5      = @n_LooseQty
               SELECT @c_Pack5     = @c_Pack
            END
            ELSE IF @n_GroupSeq = 6
            BEGIN
               SELECT @c_ExternOrderkey6 = @c_ExternOrderkey
               SELECT @c_OrderKey6 = @c_OrderKey
               SELECT @n_Qty6      = @n_LooseQty
               SELECT @c_Pack6     = @c_Pack
            END
            ELSE IF @n_GroupSeq = 7
            BEGIN
               SELECT @c_ExternOrderkey7 = @c_ExternOrderkey
               SELECT @c_OrderKey7 = @c_OrderKey
               SELECT @n_Qty7      = @n_LooseQty
               SELECT @c_Pack7     = @c_Pack

            END
            ELSE IF @n_GroupSeq = 8
            BEGIN
               SELECT @c_ExternOrderkey8 = @c_ExternOrderkey
               SELECT @c_OrderKey8 = @c_OrderKey
               SELECT @n_Qty8      = @n_LooseQty
               SELECT @c_Pack8     = @c_Pack
            END
                        
            FETCH NEXT FROM CUR_3 INTO @c_OrderKey, @c_ExternOrderkey, @n_GroupSeq, @n_Qty, @n_CaseQty, @n_LooseQty, @n_PalletQty
         END --CUR_3
         CLOSE CUR_3
         DEALLOCATE CUR_3
                     
         INSERT INTO #CONSOLIDATED VALUES (
                @n_GroupNo,
                @c_CurrLoadKey,
                @c_Route,
                @c_Storerkey,
                @c_Facility,
                @c_LOC,
                @c_ID,
                @c_SKU,
                IsNULL(@c_OrderKey1,""),
                IsNULL(@c_OrderKey2,""),
                IsNULL(@c_OrderKey3,""),
                IsNULL(@c_OrderKey4,""),
                IsNULL(@c_OrderKey5,""),
                IsNULL(@c_OrderKey6,""),
                IsNULL(@c_OrderKey7,""),
                IsNULL(@c_OrderKey8,""),
                IsNULL(@n_Qty1,0),
                IsNULL(@n_Qty2,0),
                IsNULL(@n_Qty3,0),
                IsNULL(@n_Qty4,0),
                IsNULL(@n_Qty5,0),
                IsNULL(@n_Qty6,0),
                IsNULL(@n_Qty7,0),
                IsNULL(@n_Qty8,0),
                IsNull(@c_Pack1,""),
                IsNull(@c_Pack2,""),
                IsNull(@c_Pack3,""),
                IsNull(@c_Pack4,""),
                IsNull(@c_Pack5,""),
                IsNull(@c_Pack6,""),
                IsNull(@c_Pack7,""),
                IsNull(@c_Pack8,""),
                @c_SkuDescr,
                @c_FacDescr,
                @c_Company,
                @c_UOM1,
                @c_UOM3,
                @n_CaseCnt,
                @n_Pallet,
                ISNULL(@c_ExternOrderkey1,""),
                ISNULL(@c_ExternOrderkey2,""),
                ISNULL(@c_ExternOrderkey3,""),
                ISNULL(@c_ExternOrderkey4,""),
                ISNULL(@c_ExternOrderkey5,""),
                ISNULL(@c_ExternOrderkey6,""),
                ISNULL(@c_ExternOrderkey7,""),
                ISNULL(@c_ExternOrderkey8,""),
                @c_PickSlipno,
                @c_lottable01,
                @c_lottable02,
                @c_lottable03,
                @d_lottable04,
                @c_PickType,
                @c_LEXTLoadKey,               --(CS01)
                @c_LPriority,@c_LPuserdefDate01         --(CS01)
                )
                         
         SELECT @n_PrevGroupNo = @n_GroupNo
         
         FETCH NEXT FROM CUR_2 INTO @c_LOC, @c_SKU, @c_lot, @c_ID, @n_GroupNo, @c_PickType,
                                    @c_CurrLoadkey, @c_Route, @c_Storerkey, @n_CaseCnt, @n_Pallet,
                                    @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04,
                                    @c_UOM1, @c_UOM3, @c_UOM4, @c_SkuDescr,                  
                                    @c_Facility, @c_FacDescr, @c_Company, @c_PickSlipno,
                                    @c_LEXTLoadKey,@c_LPriority,@c_LPuserdefDate01          --(CS01)                                        
      END --CUR_2
      CLOSE CUR_2
      DEALLOCATE CUR_2
            
      SELECT ConsoGroupNo,
             MAX(OrderKey1) AS Orderkey1,  
             MAX(ExternOrderkey1) AS ExternOrderkey1,
             MAX(OrderKey2) AS Orderkey2,  
             MAX(ExternOrderkey2) AS ExternOrderkey2,
             MAX(OrderKey3) AS Orderkey3,  
             MAX(ExternOrderkey3) AS ExternOrderkey3,
             MAX(OrderKey4) AS Orderkey4,  
             MAX(ExternOrderkey4) AS ExternOrderkey4,
             MAX(OrderKey5) AS Orderkey5,  
             MAX(ExternOrderkey5) AS ExternOrderkey5,
             MAX(OrderKey6) AS Orderkey6,  
             MAX(ExternOrderkey6) AS ExternOrderkey6,
             MAX(OrderKey7) AS Orderkey7,  
             MAX(ExternOrderkey7) AS ExternOrderkey7,
             MAX(OrderKey8) AS Orderkey8,  
             MAX(ExternOrderkey8) AS ExternOrderkey8
      INTO #TMP_SEQINFO
      FROM #CONSOLIDATED
      GROUP BY ConsoGroupNo
      
      UPDATE #CONSOLIDATED
      SET #CONSOLIDATED.OrderKey1 = S.Orderkey1,  
          #CONSOLIDATED.ExternOrderkey1 = S.ExternOrderkey1,
          #CONSOLIDATED.OrderKey2 = S.Orderkey2,  
          #CONSOLIDATED.ExternOrderkey2 = S.ExternOrderkey2,
          #CONSOLIDATED.OrderKey3 = S.Orderkey3,  
          #CONSOLIDATED.ExternOrderkey3 = S.ExternOrderkey3,
          #CONSOLIDATED.OrderKey4 = S.Orderkey4,  
          #CONSOLIDATED.ExternOrderkey4 = S.ExternOrderkey4,
          #CONSOLIDATED.OrderKey5 = S.Orderkey5,  
          #CONSOLIDATED.ExternOrderkey5 = S.ExternOrderkey5,
          #CONSOLIDATED.OrderKey6 = S.Orderkey6,  
          #CONSOLIDATED.ExternOrderkey6 = S.ExternOrderkey6,
          #CONSOLIDATED.OrderKey7 = S.Orderkey7,  
          #CONSOLIDATED.ExternOrderkey7 = S.ExternOrderkey7,
          #CONSOLIDATED.OrderKey8 = S.Orderkey8,  
          #CONSOLIDATED.ExternOrderkey8 = S.ExternOrderkey8
      FROM #CONSOLIDATED 
      JOIN #TMP_SEQINFO S ON #CONSOLIDATED.ConsoGroupNo = S.ConsoGroupNo         
      
      /*
      BEGIN TRAN
      
      UPDATE PICKDETAIL WITH (ROWLOCK)
      SET PICKDETAIL.Pickslipno = #TEMP_PICK.Pickslipno,
          PICKDETAIL.TrafficCop = NULL
      FROM PICKDETAIL 
      JOIN #TEMP_PICK ON PICKDETAIL.Pickdetailkey = #TEMP_PICK.Pickdetailkey      
      WHERE ISNULL(PICKDETAIL.Pickslipno,'') = ''
      	      
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         IF @@TRANCOUNT >= 1
         BEGIN
            ROLLBACK TRAN
         END
      END
      ELSE
      BEGIN
         IF @@TRANCOUNT > 0
            COMMIT TRAN
         ELSE
            ROLLBACK TRAN
      END
      */      

      SELECT C.* 
      FROM #CONSOLIDATED C
      JOIN LOC (NOLOCK)ON C.loc = LOC.loc
      ORDER BY C.Loadkey, C.Pickslipno, LOC.logicallocation
      
      DROP TABLE #CONSOLIDATED
      DROP TABLE #SKUGroup
      
      WHILE @@TRANCOUNT > 0   
         COMMIT TRAN  
      
      WHILE @@TRANCOUNT < @nStartTranCount   
         BEGIN TRAN        
END /* main procedure */


GO