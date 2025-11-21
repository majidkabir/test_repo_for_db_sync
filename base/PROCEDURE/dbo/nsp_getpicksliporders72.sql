SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  nsp_GetPickSlipOrders72                            */
/* Creation Date:03 APR 2017                                            */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  Create Pickslip for IDSTH                                  */
/*                                                                      */
/* Input Parameters:  @c_LoadKey  - Loadkey                             */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_print_pickorder72                  */
/*                             copy from r_dw_print_pickorder02a        */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.6                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[nsp_GetPickSlipOrders72] (@c_LoadKey NVARCHAR(10))
 AS
BEGIN
    SET NOCOUNT ON 
    SET QUOTED_IDENTIFIER OFF 
    SET CONCAT_NULL_YIELDS_NULL OFF
    DECLARE @c_pickheaderkey   NVARCHAR(10),
            @n_continue        INT,
            @c_errmsg          NVARCHAR(255),
            @b_success         INT,
            @n_err             INT,
            @c_sku             NVARCHAR(20),
            @n_qty             INT,
            @c_loc             NVARCHAR(10),
            @c_orderkey        NVARCHAR(10),
            @c_OHOrderkey      NVARCHAR(10),
            @c_Externorderkey  NVARCHAR(20),
            @c_ConsigneeKey    NVARCHAR(15),
            @c_Company         NVARCHAR(45),
            @c_Addr1           NVARCHAR(45),
            @c_Addr2           NVARCHAR(45),
            @c_Addr3           NVARCHAR(45),
            @c_Addr4           NVARCHAR(45),
            @c_PostCode        NVARCHAR(100),
            @c_Route           NVARCHAR(10),
            @c_Notes           NVARCHAR(60),
            @c_SkuDesc         NVARCHAR(60),
            @n_CaseCnt         INT,
            @n_PalletCnt       INT,
            @n_InnerCnt        INT,
            @n_EachCnt         INT,
            @c_PrintedFlag     NVARCHAR(1),
            @c_UOM             NVARCHAR(10),
            @c_PUOM3           NVARCHAR(10),
            @c_Lot             NVARCHAR(10),
            @c_StorerKey       NVARCHAR(15),
            @n_PgGroup         INT,
            @n_TotCases        INT,
            @n_RowNo           INT,
            @c_firstorderkey   NVARCHAR(10),
            @c_superorderflag  NVARCHAR(1),
            @c_firsttime       NVARCHAR(1),
            @c_logicalloc      NVARCHAR(18),
            @c_Lottable01      NVARCHAR(18),
            @c_Lottable02      NVARCHAR(18), 
            @c_Lottable03      NVARCHAR(18),
            @c_Lottable04      NVARCHAR(10), 
            @c_Lottable05      NVARCHAR(10),
            @d_Lottable04      DATETIME,
            @c_Lottable06      NVARCHAR(30),
            @c_Lottable07      NVARCHAR(30), 
            @c_Lottable08      NVARCHAR(30),
            @c_Lottable09      NVARCHAR(30), 
            @c_Lottable10      NVARCHAR(30),
            @d_DeliveryDate    DATETIME,
            @c_PickDate        NVARCHAR(10),
            @c_loadDate        NVARCHAR(10),
            @c_pickslipno      NVARCHAR(10),
            @c_OHFacility      NVARCHAR(10)
    
    DECLARE @c_PrevOrderKey    NVARCHAR(10),
            @n_Pallets         INT,
            @n_Cartons         INT,
            @n_Eaches          INT,
            @n_UOMQty          INT,
            @n_starttcnt       INT 
    
    DECLARE @n_qtyorder        INT,
            @n_qtyallocated    INT

   DECLARE @n_OrderRoute         INT             
         , @n_ShowUOMQty         INT             
         , @n_Pallet             FLOAT           
         , @n_InnerPack          FLOAT    
         

   DECLARE @c_LRoute        NVARCHAR(10),
           @c_LEXTLoadKey   NVARCHAR(20),
           @c_OHPriority    NVARCHAR(10),
           @c_LUdef01       NVARCHAR(20),
           @c_Lott01title   NVARCHAR(30),
           @c_Lott02title   NVARCHAR(30),  
			  @c_Lott03title   NVARCHAR(30),
			  @c_Lott04title   NVARCHAR(30),
			  @c_Lott05title   NVARCHAR(30),
			  @c_Lott06title   NVARCHAR(30),  
			  @c_Lott07title   NVARCHAR(30),  
			  @c_Lott08title   NVARCHAR(30),  
			  @c_Lott09title   NVARCHAR(30),  
			  @c_Lott10title   NVARCHAR(30)
 
     
   
   SET @n_OrderRoute = 0                         
   SET @n_ShowUOMQty = 0                         
   SET @n_Pallet     = 0.00                      
   SET @n_CaseCnt    = 0.00                      
   SET @n_InnerPack  = 0.00        
   SET @n_PgGroup = 1                 
    
    CREATE TABLE #temp_pick
    (
       PickSlipNo       NVARCHAR(10),
       LoadKey          NVARCHAR(10),
       OrderKey         NVARCHAR(10),
       Externorderkey   NVARCHAR(20),
       ConsigneeKey     NVARCHAR(15),
       Company          NVARCHAR(45),
       Addr1            NVARCHAR(45),
       Addr2            NVARCHAR(45),
       Addr3            NVARCHAR(45),
       Addr4            NVARCHAR(45),
       PostCode         NVARCHAR(100),
       ROUTE            NVARCHAR(10),
       Notes            NVARCHAR(60),
       LOC              NVARCHAR(10),
       SKU              NVARCHAR(20),
       SkuDesc          NVARCHAR(60),
       Qty              INT,
       PrintedFlag      NVARCHAR(1),
       PgGroup          INT,
       RowNum           INT,
       Lot              NVARCHAR(10),
       Lottable01       NVARCHAR(18) NULL,
       Lottable02       NVARCHAR(18) NULL,  
       Lottable03       NVARCHAR(18) NULL,
       Lottable04       NVARCHAR(10) NULL,
       Lottable05       NVARCHAR(10) NULL,
       Lottable06       NVARCHAR(30) NULL,  
       Lottable07       NVARCHAR(30) NULL,  
       Lottable08       NVARCHAR(30) NULL,  
       Lottable09       NVARCHAR(30) NULL,  
       Lottable10       NVARCHAR(30) NULL,  
       storerkey        NVARCHAR(18) NULL,
       LoadDate         NVARCHAR(10) NULL,
       deliverydate     NVARCHAR(10) NULL,
       uom3             NVARCHAR(10) NULL,  
       Pallet           FLOAT         ,
       CaseCnt          FLOAT         ,
       InnerPack        FLOAT         ,     
       LRoute           NVARCHAR(10)  NULL,     
       LPriority        NVARCHAR(10)  NULL,  
       OHFacility       NVARCHAR(10)  NULL,     
       Lott01title      NVARCHAR(30)  NULL,
       Lott02title      NVARCHAR(30) NULL,  
       Lott03title      NVARCHAR(30) NULL,
       Lott04title      NVARCHAR(30) NULL,
       Lott05title      NVARCHAR(30) NULL,
       Lott06title      NVARCHAR(30) NULL,  
       Lott07title      NVARCHAR(30) NULL,  
       Lott08title      NVARCHAR(30) NULL,  
       Lott09title      NVARCHAR(30) NULL,  
       Lott10title      NVARCHAR(30) NULL

    ) -- SOS25509
    
    SELECT @n_continue = 1,
           @n_starttcnt = @@TRANCOUNT  


   WHILE @@TRANCOUNT > 0
      COMMIT TRAN
    
    SELECT @n_RowNo = 0
    SELECT @c_firstorderkey = 'N'
    -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 8 - By Order
    IF EXISTS(
           SELECT 1
           FROM   PickHeader(NOLOCK)
           WHERE  ExternOrderKey = @c_LoadKey AND
                  Zone = '3'
       )
    BEGIN
        SELECT @c_firsttime = 'N'
        SELECT @c_PrintedFlag = 'Y'
    END
    ELSE
    BEGIN
        SELECT @c_firsttime = 'Y'
        SELECT @c_PrintedFlag = 'N'
    END -- Record Not Exists
   
    BEGIN TRAN
     
    DECLARE pick_cur           
    CURSOR LOCAL FAST_FORWARD READ_ONLY 
    FOR
        SELECT Pickdetail.Pickslipno,
               PickDetail.sku,
               PickDetail.loc,
               SUM(PickDetail.qty),
               PickDetail.storerkey,
               PickDetail.OrderKey,
               Pickdetail.Lot
        FROM   PickDetail(NOLOCK)
               JOIN LoadPlanDetail  (NOLOCK) ON PickDetail.OrderKey = LoadPlanDetail.OrderKey 
               JOIN LoadPlan   (NOLOCK) ON LoadPlan.Loadkey = LoadPlanDetail.Loadkey        
              -- JOIN PACK (NOLOCK) ON  PickDetail.Packkey = PACK.Packkey
               JOIN LOC (NOLOCK) ON LOC.Loc = PICKDETAIL.Loc
               --LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'ECLOTTABLE' AND C.storerkey = PickDetail.storerkey
        WHERE  PickDetail.Status < '9' AND 
               LoadPlanDetail.LoadKey = @c_LoadKey               
        GROUP BY Pickdetail.Pickslipno,
               PickDetail.sku,
               PickDetail.loc,
               PickDetail.storerkey,
               PickDetail.OrderKey,
               Pickdetail.Lot
        ORDER BY
               PickDetail.ORDERKEY
    
    OPEN pick_cur
    
    SELECT @c_PrevOrderKey = ''
     
    FETCH NEXT FROM pick_cur INTO @c_pickslipno,@c_sku, @c_loc, @n_Qty, @c_storerkey,
    @c_orderkey,@c_Lot  
    
    WHILE (@@FETCH_STATUS<>-1)
    BEGIN
    	  
        IF @c_OrderKey<>@c_PrevOrderKey
        BEGIN
            IF NOT EXISTS(
                   SELECT 1
                   FROM   PICKHEADER(NOLOCK)
                   WHERE  EXTERNORDERKEY = @c_LoadKey AND
                          OrderKey = @c_OrderKey AND
                          Zone = '3'
               )
            BEGIN
                EXECUTE nspg_GetKey
                'PICKSLIP',
                9, 
                @c_pickheaderkey OUTPUT,
                @b_success OUTPUT,
                @n_err OUTPUT,
                @c_errmsg OUTPUT
                
                SELECT @c_pickheaderkey = 'P'+@c_pickheaderkey
                
                INSERT INTO PICKHEADER
                  (
                    PickHeaderKey,
                    OrderKey,
                    ExternOrderKey,
                    PickType,
                    Zone,
                    TrafficCop
                  )
                VALUES
                  (
                    @c_pickheaderkey,
                    @c_OrderKey,
                    @c_LoadKey,
                    '0',
                    '3',
                    ''
                  )
                
                SELECT @n_err = @@ERROR
                IF @n_err<>0
                BEGIN
                    SET @n_continue = 3
                    SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=73000   
                    SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Failed On Table Pickheader Table. (nsp_GetPickSlipOrders26)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '  
 
                    GOTO QUIT_SP
                END
                ELSE
                BEGIN
                  WHILE @@TRANCOUNT > 0
                     COMMIT TRAN
                END 
                
                SELECT @c_firstorderkey = 'Y'
            END
            ELSE
            BEGIN
                SELECT TOP 1 
                       @c_pickheaderkey = PickHeaderKey
                FROM   PickHeader(NOLOCK)
                WHERE  ExternOrderKey = @c_LoadKey AND
                       Zone = '3' AND
                       OrderKey = @c_OrderKey
            END
        END
        
        SET @c_OHFacility = ''
        
        IF @c_OrderKey=''
        BEGIN
            SELECT @c_OHOrderkey = '',
                   @c_ConsigneeKey = '',
                   @c_Company = '',
                   @c_Addr1 = '',
                   @c_Addr2 = '',
                   @c_Addr3 = '',
                   @c_PostCode = '',
                   @c_Route = '',
                   @c_PickDate = '',
                   @c_loadDate = '',
                   @c_LRoute = '',
                   @c_Route = '',
                   @c_OHPriority = '',
                   @c_OHFacility = ''
        END
        ELSE
        BEGIN
            SELECT @c_Externorderkey = orders.Externorderkey,
                   @c_ConsigneeKey = Orders.ConsigneeKey,
                   @c_Company = ORDERS.c_Company,
                   @c_Addr1 = ORDERS.C_Address1,
                   @c_Addr2 = ORDERS.C_Address2,
                   @c_Addr3 = ORDERS.C_Address3,
                   @c_Addr4 = ORDERS.C_Address4,
                   @c_PostCode = (ORDERS.C_City + ' ' + ORDERS.C_State +' ' + ORDERS.C_Zip),
                   @c_Notes = CONVERT(NVARCHAR(60), ORDERS.Notes),           
                   @c_loadDate = ISNULL(CONVERT(NVARCHAR(10),ORDERS.Userdefine06,120),''),
                   @c_PickDate = ISNULL(CONVERT(NVARCHAR(10),ORDERS.deliverydate,120),''),
                   @c_OHOrderkey = orders.orderkey,
                   @c_Route = ORDERS.[Route],
                   @c_LRoute = ORDERS.STOP,
                   @c_OHPriority = ORDERS.Priority,
                   @c_OHFacility= ORDERS.Facility
            FROM   ORDERS WITH (NOLOCK)
            WHERE  ORDERS.OrderKey = @c_OrderKey 
        END -- IF @c_OrderKey = ''
        
        
        
        
           -- START
         --SELECT @n_OrderRoute = ISNULL(MAX(CASE WHEN CODE = 'ORDERROUTE' THEN 1 ELSE 0 END),0)  
         --      ,@n_ShowUOMQty = ISNULL(MAX(CASE WHEN CODE = 'SHOWUOMQTY' THEN 1 ELSE 0 END),0)    
         --FROM CODELKUP WITH (NOLOCK)
         --WHERE LISTNAME = 'REPORTCFG'
         --AND   Storerkey = @c_Storerkey
         --AND   Long = 'r_dw_print_pickorder72'
         --AND   ISNULL(RTRIM(Short),'') <> 'N'
         
         --IF  @n_OrderRoute = 1
         --BEGIN
         --   SELECT @c_Route = ISNULL(RTRIM(Route), '')
         --   FROM ORDERS WITH (NOLOCK)
         --   WHERE Orderkey = @c_Orderkey
         --END   
            --END
        
        SELECT @c_Lottable01 = ISNULL(Lottable01,''),
               @c_Lottable02 =  ISNULL(Lottable02,''),   
               @c_Lottable03 =  ISNULL(Lottable03,''),
               @c_Lottable04 =  ISNULL(CONVERT(NVARCHAR(10),Lottable04,120),''),
               @c_Lottable05 =  ISNULL(CONVERT(NVARCHAR(10),Lottable05,120),''),
               @c_Lottable06 =  ISNULL(Lottable06,''),
               @c_Lottable07 =  ISNULL(Lottable07,''),   
               @c_Lottable08 =  ISNULL(Lottable08,''),
               @c_Lottable09 =  ISNULL(Lottable09,''),
               @c_Lottable10 =  ISNULL(Lottable10,'')
        FROM   LOTATTRIBUTE(NOLOCK)
        WHERE  LOT = @c_LOT
        
       
        
        IF @c_Notes IS NULL
            SELECT @c_Notes = ''
        
        IF @c_Externorderkey IS NULL
            SELECT @c_Externorderkey = ''
        
        IF @c_ConsigneeKey IS NULL
            SELECT @c_ConsigneeKey = ''
        
 
        IF @c_Company IS NULL
            SELECT @c_Company = ''
        
        IF @c_Addr1 IS NULL
            SELECT @c_Addr1 = ''
        
        IF @c_Addr2 IS NULL
            SELECT @c_Addr2 = ''
        
        IF @c_Addr3 IS NULL
            SELECT @c_Addr3 = ''
        
        IF @c_PostCode IS NULL
            SELECT @c_PostCode = ''
        
        IF @c_Route IS NULL
            SELECT @c_Route = ''
      
        IF @c_SuperOrderFlag='Y'
            SELECT @c_OrderKey = ''
        
        SELECT @n_RowNo = @n_RowNo+1
        SELECT @n_Pallets = 0,
               @n_Cartons = 0,
               @n_Eaches = 0
        
        SELECT @n_UOMQty = 0
        SELECT @n_UOMQty = CASE @c_UOM
                                WHEN '1' THEN PACK.Pallet
                                WHEN '2' THEN PACK.CaseCnt
                                WHEN '3' THEN PACK.InnerPack
                                ELSE 1
                           END,
               -- @c_UOM_master = PACK.PackUOM3  -- SOS25509
               --@c_UOM_master = CASE @c_UOM
               --                     WHEN '1' THEN PACK.PackUOM4
               --                     WHEN '2' THEN PACK.PackUOM1
               --                     WHEN '6' THEN PACKUOM3
               --                     WHEN '7' THEN PACKUOM3
               --                     ELSE ''
               --                END,
               @c_SkuDesc = ISNULL(SKU.Descr, '')
            ,  @n_Pallet = PACK.Pallet                 
            ,  @n_CaseCnt= PACK.CaseCnt                
            ,  @n_InnerPack = PACK.InnerPack 
            ,  @c_PUOM3  = PACK.PackUOM3          
        FROM   SKU WITH (NOLOCK)
               JOIN PACK WITH (NOLOCK)
                    ON  (PACK.PackKey=SKU.PackKey)
        WHERE  SKU.Storerkey = @c_storerkey AND
               SKU.SKU = @c_SKU
               
               
                      SET @c_Lott01title = 'LOTTABLE01' 
                      SET @c_Lott02title = 'LOTTABLE02' 
                      SET @c_Lott03title = 'LOTTABLE03' 
                      SET @c_Lott04title = 'LOTTABLE04' 
                      SET @c_Lott05title = 'LOTTABLE05' 
                      SET @c_Lott06title = 'LOTTABLE06' 
                      SET @c_Lott07title = 'LOTTABLE07' 
                      SET @c_Lott08title = 'LOTTABLE08'              
                      SET @c_Lott09title = 'LOTTABLE09' 
                      SET @c_Lott10title = 'LOTTABLE10' 
               
               SELECT @c_Lott01title = CASE WHEN C.code = 'LOTTABLE01' THEN ISNULL(C.notes,'') ELSE 'LOTTABLE01' END,
                      @c_Lott02title = CASE WHEN C.code = 'LOTTABLE02' THEN ISNULL(C.notes,'') ELSE 'LOTTABLE02' END,
                      @c_Lott03title = CASE WHEN C.code = 'LOTTABLE03' THEN ISNULL(C.notes,'') ELSE 'LOTTABLE03' END,
                      @c_Lott04title = CASE WHEN C.code = 'LOTTABLE04' THEN ISNULL(C.notes,'') ELSE 'LOTTABLE04' END,
                      @c_Lott05title = CASE WHEN C.code = 'LOTTABLE05' THEN ISNULL(C.notes,'') ELSE 'LOTTABLE05' END,
                      @c_Lott06title = CASE WHEN C.code = 'LOTTABLE06' THEN ISNULL(C.notes,'') ELSE 'LOTTABLE06' END,
                      @c_Lott07title = CASE WHEN C.code = 'LOTTABLE07' THEN ISNULL(C.notes,'') ELSE 'LOTTABLE07' END,
                      @c_Lott08title = CASE WHEN C.code = 'LOTTABLE08' THEN ISNULL(C.notes,'') ELSE 'LOTTABLE08' END,               
                      @c_Lott09title = CASE WHEN C.code = 'LOTTABLE09' THEN ISNULL(C.notes,'') ELSE 'LOTTABLE09' END,
                      @c_Lott10title = CASE WHEN C.code = 'LOTTABLE10' THEN ISNULL(C.notes,'') ELSE 'LOTTABLE10' END
               FROM CODELKUP C WITH (NOLOCK)
               WHERE c.listname = 'ECLOTTABLE'
               AND C.storerkey = @c_storerkey
               
               
              -- SELECT @c_pickheaderkey,@c_LoadKey
        
        INSERT INTO #Temp_Pick
          (
            PickSlipNo,  
				LoadKey,     
				OrderKey,    
				Externorderkey,
				ConsigneeKey,
				Company,     
				Addr1,      
				Addr2,       
				Addr3,      
				Addr4,       
				PostCode ,   
				ROUTE ,      
				Notes,       
				LOC ,        
				SKU ,        
				SkuDesc ,    
				Qty  ,       
				PrintedFlag ,
				PgGroup ,    
				RowNum ,     
				Lot  ,       
				Lottable01,  
				Lottable02, 
				Lottable03,  
				Lottable04,  
				Lottable05, 
				Lottable06,  
				Lottable07,  
				Lottable08,  
				Lottable09,  
				Lottable10,  
				storerkey,   
				LoadDate,    
				deliverydate,
				uom3,        
				Pallet,      
				CaseCnt,     
				InnerPack,   
				LRoute,      
				LPriority, 
				OHFacility,  
				Lott01title, 
				Lott02title, 
				Lott03title, 
				Lott04title, 
				Lott05title, 
				Lott06title, 
				Lott07title, 
				Lott08title, 
				Lott09title, 
				Lott10title
                            
          )
        VALUES
          (
            @c_pickheaderkey,
            @c_LoadKey,
            @c_OrderKey,
            @c_Externorderkey,
            @c_ConsigneeKey,
            @c_Company,
            @c_Addr1,
            @c_Addr2,
            @c_Addr3,
            @c_Addr4,
            @c_PostCode,
            @c_Route,
            @c_Notes,
            @c_LOC,
            @c_SKU,
            @c_SKUDesc,
            @n_Qty,
            @c_PrintedFlag,
            @n_PgGroup,
            @n_RowNo,
            @c_Lot,
            @c_Lottable01,
            @c_Lottable02,
            @c_Lottable03,
            @c_Lottable04,
            @c_Lottable05,
            @c_Lottable06,
            @c_Lottable07,
            @c_Lottable08,
            @c_Lottable09,
            @c_Lottable10,
            @c_storerkey,
            @c_loadDate,
            @c_PickDate,
            @c_PUOM3,
            @n_Pallet,                         
            @n_CaseCnt,                        
            @n_InnerPack,                                         
            @c_LRoute,                                            
            @c_OHPriority, 
            @c_OHFacility,                     
            @c_Lott01title,
            @c_Lott02title,  
			   @c_Lott03title,
			   @c_Lott04title,
			   @c_Lott05title,
			   @c_Lott06title,  
			   @c_Lott07title,  
			   @c_Lott08title,  
			   @c_Lott09title,  
			   @c_Lott10title                        
          )
        
        SELECT @c_PrevOrderKey = @c_OrderKey
        FETCH NEXT FROM pick_cur INTO @c_pickslipno,@c_sku, @c_loc, @n_Qty, @c_storerkey,
                                       @c_orderkey,@c_Lot  
    END
    CLOSE pick_cur 
    DEALLOCATE pick_cur   
    
    --DECLARE cur1 CURSOR LOCAL FAST_FORWARD READ_ONLY 
    --FOR
    --    SELECT DISTINCT OrderKey
    --    FROM   #temp_pick
    --    WHERE  ORDERKEY<>''
    
    --OPEN cur1
    --FETCH NEXT FROM cur1 INTO @c_orderkey
    
    --WHILE (@@fetch_status<>-1)
    --BEGIN
    --    SELECT @n_qtyorder = SUM(ORDERDETAIL.OpenQty),
    --           @n_qtyallocated = SUM(ORDERDETAIL.QtyAllocated)
    --    FROM   orderdetail(NOLOCK)
    --    WHERE  ORDERDetail.orderkey = @c_orderkey
        
    --    UPDATE #temp_pick
    --    SET    QtyOrder = @n_qtyorder,
    --           QtyAllocated = @n_qtyallocated
    --    WHERE  orderkey = @c_orderkey
        
    --    FETCH NEXT FROM cur1 INTO @c_orderkey
    --END
    --CLOSE cur1
    --DEALLOCATE cur1   

    SELECT --#temp_pick.*,
            #temp_pick.PickSlipNo,  
				#temp_pick.LoadKey,     
				#temp_pick.OrderKey,    
				#temp_pick.Externorderkey,
				#temp_pick.ConsigneeKey,
				#temp_pick.Company,     
				#temp_pick.Addr1,      
				#temp_pick.Addr2,       
				#temp_pick.Addr3,      
				#temp_pick.Addr4,       
				#temp_pick.PostCode ,   
				#temp_pick.ROUTE ,      
				#temp_pick.Notes,       
				#temp_pick.LOC ,        
				#temp_pick.SKU ,        
				#temp_pick.SkuDesc ,    
				#temp_pick.Qty  ,       
				#temp_pick.PrintedFlag ,
				#temp_pick.PgGroup ,    
				#temp_pick.RowNum ,     
				#temp_pick.Lot  ,       
				#temp_pick.Lottable01,  
				#temp_pick.Lottable02, 
				#temp_pick.Lottable03,  
				#temp_pick.Lottable04,  
				#temp_pick.Lottable05, 
				#temp_pick.Lottable06,  
				#temp_pick.Lottable07,  
				#temp_pick.Lottable08,  
				#temp_pick.Lottable09,  
				#temp_pick.Lottable10,  
				#temp_pick.storerkey,   
				#temp_pick.LoadDate,    
				#temp_pick.deliverydate,
				#temp_pick.uom3,        
				#temp_pick.Pallet,      
				#temp_pick.CaseCnt,     
				#temp_pick.InnerPack,   
				#temp_pick.LRoute,      
				#temp_pick.LPriority,  
				#temp_pick.OHFacility,  
				#temp_pick.Lott01title, 
				#temp_pick.Lott02title, 
				#temp_pick.Lott03title, 
				#temp_pick.Lott04title, 
				#temp_pick.Lott05title, 
				#temp_pick.Lott06title, 
				#temp_pick.Lott07title, 
				#temp_pick.Lott08title, 
				#temp_pick.Lott09title, 
				#temp_pick.Lott10title     
    FROM   #temp_pick
    ORDER BY #temp_pick.PickSlipNo,#temp_pick.LOC , #temp_pick.SKU 
  
  
QUIT_SP:
    
   WHILE @@TRANCOUNT < @n_StartTCnt
      BEGIN TRAN 

   /* #INCLUDE <SPTPA01_2.SQL> */  
   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_success = 0  
      IF @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'nsp_GetPickSlipWave_72'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SELECT @b_success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
   END

END


GRANT EXECUTE ON nsp_GetPickSlipOrders72 TO NSQL

GO