SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Stored Procedure: nspConsolidatedPickList36                             */
/* Creation Date:                                                          */
/* Copyright: IDS                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: Duplicated from nspConsolidatedPickList01                      */
/*                                                                         */
/* Called By: r_dw_consolidated_pick36                                     */
/*                                                                         */
/* PVCS Version: 1.1                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 29-Apr-2015  CSCHONG 1.0   SOS339808  (CS01)                            */
/* 09-Jul-2015  CSCHONG 1.1   SOS346307  (CS02)                            */
/***************************************************************************/
CREATE PROC [dbo].[nspConsolidatedPickList36] (  
 @a_s_LoadKey  NVARCHAR(10)  
 )  
 AS  
 BEGIN     
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   SET ANSI_NULLS OFF          
  
 DECLARE @d_date_start  datetime,  
      @d_date_end       datetime,  
      @c_sku            NVARCHAR(20),  
      @c_storerkey      NVARCHAR(15),  
      @c_lot            NVARCHAR(10),  
      @c_uom            NVARCHAR(10),  
      @c_Route          NVARCHAR(10),  
      @c_Exe_String     NVARCHAR(60),  
      @n_Qty            int,  
      @c_Pack           NVARCHAR(10),  
      @n_CaseCnt        int,  
      @c_uom1           NVARCHAR(10),  
      @c_uom3           NVARCHAR(10)  
  
 DECLARE @c_CurrOrderKey NVARCHAR(10),  
      @c_MBOLKey         NVARCHAR(10),  
      @c_firsttime       NVARCHAR(1),  
      @c_PrintedFlag     NVARCHAR(1),  
      @n_err             int,  
      @n_continue        int,  
      @c_PickHeaderKey   NVARCHAR(10),  
      @b_success         int,  
      @c_errmsg          NVARCHAR(255)  
  
 DECLARE @nStartTranCount int  
  
 SET @nStartTranCount = @@TRANCOUNT   
  
 BEGIN TRAN  
  
 /*Start Modification */  
   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 7 - Consolidated pick list , 8 - By Order  
   IF EXISTS(SELECT 1 FROM PickHeader (NOLOCK)   
             WHERE ExternOrderKey = @a_s_LoadKey  
             AND   Zone = '7')  
   BEGIN  
  
      SELECT @c_firsttime = 'N'  
      SELECT @c_PrintedFlag = 'Y'  
  
      -- Uses PickType as a Printed Flag  
      UPDATE PickHeader WITH (ROWLOCK)   
      SET PickType = '1',  
          TrafficCop = NULL  
      WHERE ExternOrderKey = @a_s_LoadKey  
      AND Zone = '7'  
      AND PickType = '0'  
   END  
   ELSE  
   BEGIN  
      SELECT @c_firsttime = 'Y'  
      SELECT @c_PrintedFlag = 'N'  
   END -- Record Not Exists  
     
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
      WHILE @@TRANCOUNT > 0   
      BEGIN  
         COMMIT TRAN  
      END  
   END  
   IF @c_firsttime = 'Y'  
   BEGIN  
      EXECUTE dbo.nspg_GetKey  
      'PICKSLIP',  
      9,     
      @c_pickheaderkey     OUTPUT,  
      @b_success      OUTPUT,  
      @n_err          OUTPUT,  
      @c_errmsg       OUTPUT  
        
      SELECT @c_pickheaderkey = 'P' + @c_pickheaderkey  
  
      INSERT INTO PICKHEADER  
      (PickHeaderKey,  ExternOrderKey, PickType, Zone, TrafficCop)  
      VALUES  
      (@c_pickheaderkey, @a_s_LoadKey,     '0',      '7',  '')  
        
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
         WHILE @@TRANCOUNT > 0   
            COMMIT TRAN  
      END  
   END  
   ELSE  
   BEGIN  
      SELECT @c_pickheaderkey = PickHeaderKey   
      FROM  PickHeader (NOLOCK)   
      WHERE ExternOrderKey = @a_s_LoadKey  
      AND   Zone = '7'  
   END  
 /* End */  
 /*Create Temp Result table */  
   SELECT  ConsoGroupNo = 0,  
        Loadplan.LoadKey LoadKey,  
        PICKDETAIL.LOC Loc,  
        PICKDETAIL.SKU SKU,  
        ORDERS.StorerKey StorerKey1,  
        ORDERS.OrderKey  OrderKey1,  
        ORDERS.Route     Route1,  
        ORDERS.StorerKey StorerKey2,  
        ORDERS.OrderKey  OrderKey2,  
        ORDERS.Route     Route2,  
        ORDERS.StorerKey StorerKey3,  
        ORDERS.OrderKey  OrderKey3,  
        ORDERS.Route     Route3,  
        ORDERS.StorerKey StorerKey4,  
        ORDERS.OrderKey  OrderKey4,  
        ORDERS.Route     Route4,  
        ORDERS.StorerKey StorerKey5,  
        ORDERS.OrderKey  OrderKey5,  
        ORDERS.Route     Route5,  
        ORDERS.StorerKey StorerKey6,  
        ORDERS.OrderKey  OrderKey6,  
        ORDERS.Route     Route6,  
        ORDERS.StorerKey StorerKey7,  
        ORDERS.OrderKey  OrderKey7,  
        ORDERS.Route     Route7,  
        ORDERS.StorerKey StorerKey8,  
        ORDERS.OrderKey  OrderKey8,  
        ORDERS.Route     Route8,  
        PICKDETAIL.QTY   Qty1,  
        PICKDETAIL.QTY   Qty2,  
        PICKDETAIL.QTY   Qty3,  
        PICKDETAIL.QTY   Qty4,  
        PICKDETAIL.QTY   Qty5,  
        PICKDETAIL.QTY   Qty6,  
        PICKDETAIL.QTY   Qty7,  
        PICKDETAIL.QTY   Qty8,  
        Pack1=Convert(NVarchar(10), ''),  -- Space(10),  
        Pack2=Convert(NVarchar(10), ''),  -- Space(10),  
        Pack3=Convert(NVarchar(10), ''),  -- Space(10),  
        Pack4=Convert(NVarchar(10), ''),  -- Space(10),  
        Pack5=Convert(NVarchar(10), ''),  -- Space(10),  
        Pack6=Convert(NVarchar(10), ''),  -- Space(10),  
        Pack7=Convert(NVarchar(10), ''),  -- Space(10),  
        Pack8=Convert(NVarchar(10), ''),  -- Space(10),  
        TotQty=0,  
        TotCases=0,  
        TotPack= Convert(NVarchar(10), ''),  -- Space(10),  
        DESCR  = Convert(NVarchar(60), ''),  -- Space(60),  
        UOM1= Convert(NVarchar(10), ''),  -- Space(10),  
        UOM3= Convert(NVarchar(10), ''),  -- Space(10),  
        CaseCnt=0,  
        ORDERS.ExternOrderKey InvoiceNo1,   
        ORDERS.ExternOrderKey InvoiceNo2,   
        ORDERS.ExternOrderKey InvoiceNo3,   
        ORDERS.ExternOrderKey InvoiceNo4,   
        ORDERS.ExternOrderKey InvoiceNo5,   
        ORDERS.ExternOrderKey InvoiceNo6,   
        ORDERS.ExternOrderKey InvoiceNo7,  
        ORDERS.ExternOrderKey InvoiceNo8,  
        LabelFlag='N' ,  
        PICKDETAIL.LOT Lot,  
        LOTATTRIBUTE.Lottable01 lottable1,  
        LOTATTRIBUTE.Lottable02 lottable2,  
        LOTATTRIBUTE.Lottable03 lottable3,  
        LOTATTRIBUTE.Lottable04 lottable4,  
        LOTATTRIBUTE.Lottable05 lottable5,  
        PickHeaderKey = Convert(NVarchar(10), ''),  -- space(10),  
        C_Company1 = Convert(NVarchar(45), ''),  -- SPACE(45),  
        C_Company2 = Convert(NVarchar(45), ''),  -- SPACE(45),  
        C_Company3 = Convert(NVarchar(45), ''),  -- SPACE(45),  
        C_Company4 = Convert(NVarchar(45), ''),  -- SPACE(45),  
        C_Company5 = Convert(NVarchar(45), ''),  -- SPACE(45),  
        C_Company6 = Convert(NVarchar(45), ''),  -- SPACE(45),  
        C_Company7 = Convert(NVarchar(45), ''),  -- SPACE(45),  
        C_Company8 = Convert(NVarchar(45), ''),  -- SPACE(45),  
        printflag  = Convert(NVarchar(10), ''),  -- space(10)  
        LRoute = Loadplan.Route ,
        LEXTLoadKey = Loadplan.Externloadkey,
        LPriority = Loadplan.Priority,
        --LUdef01 = Loadplan.UserDefine01             --(CS01) --(CS02)
        LUdef01 = REPLACE(CONVERT(NVARCHAR(12),Loadplan.LPuserdefDate01,106),' ','/') --(CS02)
   INTO #CONSOLIDATED   
   FROM LOADPLAN (NOLOCK), ORDERS (NOLOCK), PICKDETAIL (NOLOCK), LOTATTRIBUTE(NOLOCK)  
   where 1 = 2  
     
   DECLARE @c_Route1     NVARCHAR(10),  
           @c_StorerKey1 NVARCHAR(15),  
           @c_OrderKey1  NVARCHAR(10),  
           @c_Route2     NVARCHAR(10),  
           @c_StorerKey2 NVARCHAR(15),  
           @c_OrderKey2  NVARCHAR(10),  
           @c_Route3     NVARCHAR(10),  
           @c_StorerKey3 NVARCHAR(15),  
           @c_OrderKey3  NVARCHAR(10),  
           @c_Route4     NVARCHAR(10),  
           @c_StorerKey4 NVARCHAR(15),  
           @c_OrderKey4  NVARCHAR(10),  
           @c_Route5     NVARCHAR(10),  
           @c_StorerKey5 NVARCHAR(15),  
           @c_OrderKey5  NVARCHAR(10),  
           @c_Route6     NVARCHAR(10),  
           @c_StorerKey6 NVARCHAR(15),  
           @c_OrderKey6  NVARCHAR(10),  
           @c_Route7     NVARCHAR(10),  
           @c_StorerKey7 NVARCHAR(15),  
           @c_OrderKey7  NVARCHAR(10),  
           @c_Route8     NVARCHAR(10),  
           @c_StorerKey8 NVARCHAR(15),  
           @c_OrderKey8  NVARCHAR(10)  
    
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
           @c_Pack8  NVARCHAR(10),  
           @n_TotQty   int,  
           @c_TotPack  NVARCHAR(10),  
           @n_TotCases int,  
           @n_CasesQty int,  
           @c_Descr    NVARCHAR(60),  
           @c_Packkey  NVARCHAR(10)  
    
   DECLARE @c_Invoice1 NVARCHAR(18),  
           @c_Invoice2 NVARCHAR(18),  
           @c_Invoice3 NVARCHAR(18),  
           @c_Invoice4 NVARCHAR(18),  
           @c_Invoice5 NVARCHAR(18),  
           @c_Invoice6 NVARCHAR(18),  
           @c_Invoice7 NVARCHAR(18),  
           @c_Invoice8 NVARCHAR(18)  
    
   declare @c_company1 NVARCHAR(45),  
           @c_company2 NVARCHAR(45),  
           @c_company3 NVARCHAR(45),  
           @c_company4 NVARCHAR(45),  
           @c_company5 NVARCHAR(45),  
           @c_company6 NVARCHAR(45),  
           @c_company7 NVARCHAR(45),  
           @c_company8 NVARCHAR(45)  
     
   declare @c_company NVARCHAR(45),  
           @c_invoiceno NVARCHAR(18),  
           @c_printflag NVARCHAR(10)  
    
   CREATE TABLE #SKUGroup (  
           LOC      NVARCHAR(10),  
           SKU      NVARCHAR(20),  
           OrderKey NVARCHAR(10),  
           GroupNo  int,  
           GroupSeq INT,
           Lot      NVARCHAR(10),
           Storerkey NVARCHAR(15))  
    
   -- Do a grouping for sku  
   DECLARE @c_OrderKey NVARCHAR(10),  
           @c_Invoice     NVARCHAR(18),  
           @c_LOC         NVARCHAR(10),  
           @n_Count       int,  
           @n_GroupNo     int,  
           @n_GroupSeq    int,  
           @c_logicallocation NVARCHAR(18),  
           @n_groupno1    int,  
           @n_groupseq1   int,
           @n_prevgroupno int

   /*CS01 Start*/
   DECLARE @c_LRoute      NVARCHAR(10),
           @c_LEXTLoadKey NVARCHAR(20),
           @c_LPriority   NVARCHAR(10),
           @c_LUdef01     NVARCHAR(20)
  

    SET @c_LRoute = ''
    SET @c_LEXTLoadKey = ''
    SET @c_LPriority = ''
    SET @c_LUdef01 = ''
   /*CS01 END*/

  
    
   DECLARE CUR_1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT PICKDETAIL.OrderKey,  
     PICKDETAIL.SKU,  
     PICKDETAIL.LOC,  
     LOC.LogicalLocation,  
     PICKDETAIL.LOT,
     ORDERS.Storerkey  
   FROM PICKDETAIL (NOLOCK), LOC (nolock), ORDERS (nolock)  
   WHERE orders.loadkey = @a_s_loadkey  
     and orders.orderkey = PICKDETAIL.orderkey  
     and PICKDETAIL.loc = loc.loc  
     and PICKDETAIL.qty > 0  
   ORDER BY LOC.LogicalLocation, PICKDETAIL.LOC, PICKDETAIL.SKU, PICKDETAIL.OrderKey  
    
   OPEN CUR_1  
   SELECT @n_GroupNo = 1  
   SELECT @n_GroupSeq = 0  
   FETCH NEXT FROM CUR_1 INTO @c_OrderKey, @c_SKU, @c_Loc, @c_logicallocation, @c_lot, @c_Storerkey  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      SELECT @n_Count = Count(*)  
      FROM   #SKUGroup  
      WHERE  OrderKey = @c_OrderKey  
      IF @n_Count = 0  
      BEGIN  
         SELECT @n_GroupSeq = @n_GroupSeq + 1  
        -- Customize For Thailand for 3 Orders per pick slip  
         IF @n_GroupSeq > 3  
         BEGIN  
            SELECT @n_GroupNo=@n_GroupNo + 1  
            SELECT @n_GroupSeq = 1  
         END  
         INSERT INTO #SKUGroup   
           ( LOC, SKU, OrderKey, GroupNo, GroupSeq, Lot, Storerkey)  
            VALUES (@c_loc, @c_sku, @c_OrderKey, IsNULL(@n_GroupNo,  1), IsNULL(@n_GroupSeq, 1), @c_Lot, @c_Storerkey)  
      END -- IF ORDERKEY NOT EXIST  
      ELSE  
      BEGIN  
        IF NOT EXISTS (SELECT 1 from #skugroup where loc = @c_loc   
                         and sku = @c_sku and orderkey = @c_orderkey and lot=@c_lot)  
        BEGIN  
           SELECT @n_groupno1 = groupno, @n_groupseq1 = groupseq  
           FROM #SKUGROUP  
           WHERE orderkey = @c_orderkey  
    
           INSERT INTO #SKUGroup values (@c_loc, @c_sku, @c_orderkey, @n_groupno1, @n_groupseq1, @c_Lot, @c_Storerkey)  
        end  
      end  
      FETCH NEXT FROM CUR_1 INTO @c_OrderKey, @c_SKU, @c_Loc, @c_logicallocation, @c_lot, @c_Storerkey  
   END -- WHILE FETCH STATUS <> -1  
   CLOSE CUR_1  
   DEALLOCATE CUR_1  

   select @c_pickheaderkey = pickheaderkey, @c_printflag = picktype  
   from pickheader (nolock)  
   where externorderkey = @a_s_loadkey  
     and zone = '7'  
     
   DECLARE CUR_2 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT DISTINCT GroupNo, LOC, SKU, LOT, Storerkey  
      FROM   #SKUGroup  
      ORDER BY GroupNo, LOC, SKU, LOT 
   OPEN CUR_2  
   
   SET @n_PrevGroupNo = 0
   FETCH NEXT FROM CUR_2 INTO @n_GroupNo, @c_LOC, @c_SKU, @c_Lot, @c_Storerkey  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN   
   	 IF @n_PrevGroupno <>  @n_GroupNo
   	 BEGIN
        SELECT @c_storerkey1='', @c_storerkey2='', @c_storerkey3='', @c_storerkey4='', @c_storerkey5='', @c_storerkey6='', @c_storerkey7='', @c_storerkey8=''  
        SELECT @c_company1='', @c_company2='', @c_company3='', @c_company4='', @c_company5='', @c_company6='', @c_company7='', @c_company8=''  
        SELECT @c_route1='', @c_route2='', @c_route3='', @c_route4='', @c_route5='', @c_route6='', @c_route7='', @c_route8=''  
        SELECT @c_invoice1='', @c_invoice2='', @c_invoice3='', @c_invoice4='', @c_invoice5='', @c_invoice6='', @c_invoice7='', @c_invoice8=''  
        SELECT @c_orderkey1='', @c_orderkey2='', @c_orderkey3='', @c_orderkey4='', @c_orderkey5='', @c_orderkey6='', @c_orderkey7='', @c_orderkey8=''  
   	 END
   	
     SELECT @n_CaseCnt = 0     
     
     SELECT @n_CaseCnt = ISNULL(CaseCnt,0), @c_descr = descr, @c_uom1 = packuom1, @c_uom3 = packuom3  
     FROM   SKU (NOLOCK), PACK (NOLOCK)  
     WHERE  sku.storerkey = @c_storerkey  
       AND sku.sku = @c_sku  
       AND sku.packkey = pack.packkey  

     DECLARE CUR_3 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
         SELECT ORDERKEY,GroupSeq  
         FROM   #SKUGroup  
         WHERE  LOC = @c_LOC  
         AND    SKU = @c_SKU
         AND    LOT = @c_Lot 
         AND    GroupNo = @n_GroupNo 
         AND    Storerkey = @c_Storerkey
         ORDER BY GroupSeq
      OPEN CUR_3  
      FETCH NEXT FROM CUR_3 INTO @c_OrderKey, @n_GroupSeq  

      SELECT @n_TotQty=0, @n_TotCases=0, @c_TotPack=''  
      SELECT @n_Qty1=0, @n_Qty2=0, @n_Qty3=0, @n_Qty4=0, @n_Qty5=0, @n_Qty6=0, @n_Qty7=0, @n_Qty8=0  
      SELECT @c_Pack1='', @c_Pack2='', @c_Pack3='', @c_Pack4='', @c_Pack5='', @c_Pack6='', @c_Pack7='', @c_Pack8=''  

      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         SELECT @c_Pack = ''  
         SELECT @n_Qty = 0
         SELECT @n_CasesQty = 0  

         SELECT @n_Qty = SUM(PICKDETAIL.QTY)  
         FROM   PICKDETAIL (NOLOCK)  
         WHERE  PICKDETAIL.OrderKey = @c_OrderKey  
         AND    PICKDETAIL.SKU   = @c_SKU  
         AND    PICKDETAIL.LOC  = @c_LOC  
         AND    PICKDETAIL.Lot = @c_Lot
        
         IF @n_CaseCnt = 0  
            SELECT @c_Pack = ' ' -- No of Item in Carton not available  
         ELSE  
         BEGIN  
            SELECT @c_Pack = CONVERT(char(10), FLOOR(@n_Qty / @n_CaseCnt)) -- modified by Jacob, date: July 23, 2001. description:Changed from NVARCHAR(4) to NVARCHAR(10)  
            IF @c_Pack = '0' select @c_Pack = ''  
            SELECT @n_CasesQty = FLOOR(@n_Qty / @n_CaseCnt)  
            SELECT @n_Qty = @n_Qty % @n_CaseCnt  
         END  
         SELECT @n_TotQty   = @n_TotQty  + @n_Qty  
         SELECT @n_TotCases = @n_TotCases + @n_CasesQty  

         IF @n_GroupSeq = 1  
         BEGIN  
            SELECT @n_Qty1      = @n_Qty  
            SELECT @c_Pack1     = @c_Pack  
            select @c_storerkey1 = orders.storerkey, @c_company1 = c_company, @c_route1 = route, @c_invoice1 = externorderkey, @c_orderkey1 = orders.orderkey  
            from orders (nolock) join #skugroup  
              on orders.orderkey = #skugroup.orderkey  
            where groupseq = 1  
            and groupno = @n_GroupNo
         END  
         ELSE IF @n_GroupSeq = 2  
         BEGIN  
            SELECT @n_Qty2      = @n_Qty  
            SELECT @c_Pack2     = @c_Pack  
            select @c_storerkey2 = orders.storerkey, @c_company2 = c_company, @c_route2 = route, @c_invoice2 = externorderkey, @c_orderkey2 = orders.orderkey  
            from orders (nolock) join #skugroup  
              on orders.orderkey = #skugroup.orderkey  
            where groupseq = 2   
            and groupno = @n_GroupNo            
         END  
         ELSE IF @n_GroupSeq = 3  
         BEGIN  
            SELECT @n_Qty3      = @n_Qty  
            SELECT @c_Pack3     = @c_Pack  
            select @c_storerkey3 = orders.storerkey, @c_company3 = c_company, @c_route3 = route, @c_invoice3 = externorderkey, @c_orderkey3 = orders.orderkey  
            from orders (nolock) join #skugroup  
              on orders.orderkey = #skugroup.orderkey  
            where groupseq = 3  
            and groupno = @n_GroupNo
         END  
         ELSE IF @n_GroupSeq = 4  
         BEGIN  
            SELECT @n_Qty4      = @n_Qty  
            SELECT @c_Pack4     = @c_Pack  
            select @c_storerkey4 = orders.storerkey, @c_company4 = c_company, @c_route4 = route, @c_invoice4 = externorderkey, @c_orderkey4 = orders.orderkey  
            from orders (nolock) join #skugroup  
              on orders.orderkey = #skugroup.orderkey  
            where groupseq = 4  
            and groupno = @n_GroupNo
          END  
         ELSE IF @n_GroupSeq = 5  
         BEGIN  
            SELECT @n_Qty5      = @n_Qty  
            SELECT @c_Pack5     = @c_Pack  
            select @c_storerkey5 = orders.storerkey, @c_company5 = c_company, @c_route5 = route, @c_invoice5 = externorderkey, @c_orderkey5 = orders.orderkey  
            from orders (nolock) join #skugroup  
              on orders.orderkey = #skugroup.orderkey  
            where groupseq = 5  
            and groupno = @n_GroupNo
         END  
         ELSE IF @n_GroupSeq = 6  
         BEGIN  
            SELECT @n_Qty6      = @n_Qty  
            SELECT @c_Pack6     = @c_Pack  
            select @c_storerkey6 = orders.storerkey, @c_company6 = c_company, @c_route6 = route, @c_invoice6 = externorderkey, @c_orderkey6 = orders.orderkey  
            from orders (nolock) join #skugroup  
              on orders.orderkey = #skugroup.orderkey  
            where groupseq = 6  
            and groupno = @n_GroupNo
         END  
         ELSE IF @n_GroupSeq = 7  
         BEGIN  
            SELECT @n_Qty7      = @n_Qty  
            SELECT @c_Pack7     = @c_Pack  
            select @c_storerkey7 = orders.storerkey, @c_company7 = c_company, @c_route7 = route, @c_invoice7 = externorderkey, @c_orderkey7 = orders.orderkey  
            from orders (nolock) join #skugroup  
              on orders.orderkey = #skugroup.orderkey  
            where groupseq = 7  
            and groupno = @n_GroupNo
         END  
         ELSE IF @n_GroupSeq = 8  
         BEGIN  
            SELECT @n_Qty8      = @n_Qty  
            SELECT @c_Pack8     = @c_Pack  
            select @c_storerkey8 = orders.storerkey, @c_company8 = c_company, @c_route8 = route, @c_invoice8 = externorderkey, @c_orderkey8 = orders.orderkey  
            from orders (nolock) join #skugroup  
              on orders.orderkey = #skugroup.orderkey  
            where groupseq = 8  
            and groupno = @n_GroupNo
         END  

         FETCH NEXT FROM CUR_3 INTO @c_OrderKey, @n_GroupSeq  
      END  
      CLOSE CUR_3  
      DEALLOCATE CUR_3  

      IF @n_CaseCnt <> 0   
         SELECT @c_TotPack = CONVERT(char(10), @n_TotCases)-- modified by Jacob, date: July 23, 2001. description:Changed from NVARCHAR(4) to NVARCHAR(10)  
      ELSE  
         SELECT @c_TotPack = ''  

      /*CS01 Start*/
        SELECT @c_LRoute =   L.Route,
               @c_LEXTLoadKey = L.ExternLoadKey,
               @c_LPriority   = L.Priority,
               --@c_LUdef01     = L.UserDefine01   --(CS01)
               @c_LUdef01 = REPLACE(CONVERT(NVARCHAR(12),L.LPuserdefDate01,106),' ','/') --(CS02)
        FROM  LOADPLAN L WITH (NOLOCK)
        WHERE Loadkey = @a_s_LoadKey
 
 
      /*CS01 End*/
        
      INSERT INTO #CONSOLIDATED VALUES (  
            @n_GroupNo,  
            @a_s_LoadKey,  
            @c_LOC,  
            @c_SKU,  
            IsNULL(@c_StorerKey1,''),  
            IsNULL(@c_OrderKey1,''),  
            IsNULL(@c_Route1,''),     
            IsNULL(@c_StorerKey2,''),  
            IsNULL(@c_OrderKey2,''),  
            IsNULL(@c_Route2,''),  
            IsNULL(@c_StorerKey3,''),  
            IsNULL(@c_OrderKey3,''),  
            IsNULL(@c_Route3,''),  
            IsNULL(@c_StorerKey4,''),  
            IsNULL(@c_OrderKey4,''),  
            IsNULL(@c_Route4,''),  
            IsNULL(@c_StorerKey5,''),  
            IsNULL(@c_OrderKey5,''),  
            IsNULL(@c_Route5,''),  
            IsNULL(@c_StorerKey6,''),  
            IsNULL(@c_OrderKey6,''),  
            IsNULL(@c_Route6,''),  
            IsNULL(@c_StorerKey7,''),  
            IsNULL(@c_OrderKey7,''),  
            IsNULL(@c_Route7,''),  
            IsNULL(@c_StorerKey8,''),  
            IsNULL(@c_OrderKey8,''),  
            IsNULL(@c_Route8,''),  
            IsNULL(@n_Qty1,0),  
            IsNULL(@n_Qty2,0),  
            IsNULL(@n_Qty3,0),  
            IsNULL(@n_Qty4,0),  
            IsNULL(@n_Qty5,0),  
            IsNULL(@n_Qty6,0),  
            IsNULL(@n_Qty7,0),  
            IsNULL(@n_Qty8,0),  
            IsNull(@c_Pack1,''),  
            IsNull(@c_Pack2,''),  
            IsNull(@c_Pack3,''),  
            IsNull(@c_Pack4,''),  
            IsNull(@c_Pack5,''),  
            IsNull(@c_Pack6,''),  
            IsNull(@c_Pack7,''),  
            IsNull(@c_Pack8,''),  
            IsNull(@n_TotQty,0),  
            IsNull(@n_TotCases,0),  
            IsNull(@c_TotPack,''),  
            @c_descr,  
            @c_uom1,  
            @c_uom3,  
            @n_casecnt,  
            ISNULL(@c_Invoice1,''),  
            ISNULL(@c_Invoice2,''),  
            ISNULL(@c_Invoice3,''),  
            ISNULL(@c_Invoice4,''),  
            ISNULL(@c_Invoice5,''),  
            ISNULL(@c_Invoice6,''),  
            ISNULL(@c_Invoice7,''),  
            ISNULL(@c_Invoice8,''),  
            'Y',  
            @c_lot,  
            '',  
            '',  
            '',  
            '',  
            '',  
            @c_pickheaderkey,  
            isnull(@c_company1,''),  
            isnull(@c_company2,''),  
            isnull(@c_company3,''),  
            isnull(@c_company4,''),  
            isnull(@c_company5,''),  
            isnull(@c_company6,''),  
            isnull(@c_company7,''),  
            isnull(@c_company8,''),  
            @c_printflag ,
            @c_LRoute,              --(CS01)
            @c_LEXTLoadKey,         --(CS01)
            @c_LPriority,            --(CS01) 
            @c_LUdef01               --(CS01) 
            )         
      
      SET @n_PrevGroupNo = @n_GroupNo
      
      FETCH NEXT FROM CUR_2 INTO @n_GroupNo, @c_LOC, @c_SKU, @c_Lot, @c_Storerkey  
   END  
   CLOSE CUR_2  
   DEALLOCATE CUR_2  
   
   SELECT ConsoGroupNo,
          MAX(StorerKey1) AS Storerkey1,  
          MAX(OrderKey1) AS Orderkey1,  
          MAX(Route1) AS Route1, 
          MAX(InvoiceNo1) AS InvoiceNo1,
          MAX(C_Company1) AS C_Company1,
          MAX(StorerKey2) AS Storerkey2,  
          MAX(OrderKey2) AS Orderkey2,  
          MAX(Route2) AS Route2, 
          MAX(InvoiceNo2) AS InvoiceNo2,
          MAX(C_Company2) AS C_Company2,
          MAX(StorerKey3) AS Storerkey3,  
          MAX(OrderKey3) AS Orderkey3,  
          MAX(Route3) AS Route3, 
          MAX(InvoiceNo3) AS InvoiceNo3,
          MAX(C_Company3) AS C_Company3,
          MAX(StorerKey4) AS Storerkey4,  
          MAX(OrderKey4) AS Orderkey4,  
          MAX(Route4) AS Route4, 
          MAX(InvoiceNo4) AS InvoiceNo4,
          MAX(C_Company4) AS C_Company4,
          MAX(StorerKey5) AS Storerkey5,  
          MAX(OrderKey5) AS Orderkey5,  
          MAX(Route5) AS Route5, 
          MAX(InvoiceNo5) AS InvoiceNo5,
          MAX(C_Company5) AS C_Company5,
          MAX(StorerKey6) AS Storerkey6,  
          MAX(OrderKey6) AS Orderkey6,  
          MAX(Route6) AS Route6, 
          MAX(InvoiceNo6) AS InvoiceNo6,
          MAX(C_Company6) AS C_Company6
   INTO #TMP_SEQINFO
   FROM #CONSOLIDATED
   GROUP BY ConsoGroupNo
   
   UPDATE #CONSOLIDATED
   SET #CONSOLIDATED.Storerkey1 = S.Storerkey1,  
       #CONSOLIDATED.OrderKey1 = S.Orderkey1,  
       #CONSOLIDATED.Route1 = S.Route1, 
       #CONSOLIDATED.InvoiceNo1 = S.InvoiceNo1,
       #CONSOLIDATED.C_Company1 = S.C_Company1,
       #CONSOLIDATED.StorerKey2 = S.Storerkey2,  
       #CONSOLIDATED.OrderKey2 = S.Orderkey2,  
       #CONSOLIDATED.Route2 = S.Route2, 
       #CONSOLIDATED.InvoiceNo2 = S.InvoiceNo2,
       #CONSOLIDATED.C_Company2 = S.C_Company2,
       #CONSOLIDATED.StorerKey3 = S.Storerkey3,  
       #CONSOLIDATED.OrderKey3 = S.Orderkey3,  
       #CONSOLIDATED.Route3 = S.Route3, 
       #CONSOLIDATED.InvoiceNo3 = S.InvoiceNo3,
       #CONSOLIDATED.C_Company3 = S.C_Company3,
       #CONSOLIDATED.StorerKey4 = S.Storerkey4,  
       #CONSOLIDATED.OrderKey4 = S.Orderkey4,  
       #CONSOLIDATED.Route4 = S.Route4, 
       #CONSOLIDATED.InvoiceNo4 = S.InvoiceNo4,
       #CONSOLIDATED.C_Company4 = S.C_Company4,
       #CONSOLIDATED.StorerKey5 = S.Storerkey5,  
       #CONSOLIDATED.OrderKey5 = S.Orderkey5,  
       #CONSOLIDATED.Route5 = S.Route5, 
       #CONSOLIDATED.InvoiceNo5 = S.InvoiceNo5,
       #CONSOLIDATED.C_Company5 = S.C_Company5,
       #CONSOLIDATED.StorerKey6 = S.Storerkey6,  
       #CONSOLIDATED.OrderKey6 = S.Orderkey6,  
       #CONSOLIDATED.Route6 = S.Route6, 
       #CONSOLIDATED.InvoiceNo6 = S.InvoiceNo6,
       #CONSOLIDATED.C_Company6 = S.C_Company6
   FROM #CONSOLIDATED 
   JOIN #TMP_SEQINFO S ON #CONSOLIDATED.ConsoGroupNo = S.ConsoGroupNo         
           
    UPDATE #CONSOLIDATED  
      SET LOTTABLE1 = LOTATTRIBUTE.LOTTABLE01,  
       LOTTABLE2 = LOTATTRIBUTE.LOTTABLE02,  
       LOTTABLE3 = LOTATTRIBUTE.LOTTABLE03,  
       LOTTABLE4 = LOTATTRIBUTE.LOTTABLE04,  
       LOTTABLE5 = LOTATTRIBUTE.LOTTABLE05  
    FROM LOTATTRIBUTE (nolock)   
    WHERE #CONSOLIDATED.Lot = LOTATTRIBUTE.Lot  
     
    SELECT * FROM #CONSOLIDATED  
     
    DROP TABLE #CONSOLIDATED  
    DROP TABLE #SKUGroup  
   
   WHILE @@TRANCOUNT > 0   
      COMMIT TRAN  
   
   WHILE @@TRANCOUNT < @nStartTranCount   
      BEGIN TRAN  
    
 END /* main procedure */  

GO