SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/    
/* Stored Procedure: isp_RPT_LP_PLISTN_030                               */    
/* Creation Date: 28-FEb-2023                                            */    
/* Copyright: LFL                                                        */    
/* Written by: CSCHONG                                                   */    
/*                                                                       */    
/* Purpose: WMS-21846-SG âˆš MNC âˆš MTO Picking Slip                        */    
/*                                                                       */    
/* Called By: RPT_LP_PLISTN_030                                          */    
/*                                                                       */    
/* GitLab Version: 1.0                                                   */    
/*                                                                       */    
/* Version: 5.4                                                          */    
/*                                                                       */    
/* Data Modifications:                                                   */    
/*                                                                       */    
/* Updates:                                                              */    
/* Date        Author  Ver   Purposes                                    */    
/* 28-Feb-2023 CSCHONG 1.0   DevOps Combine Script                       */    
/* 12-MAY-2023 CSCHONG 1.1   WMS-21846 increase field length (CS01)      */
/* 17-MAY-2023 CHONGCS 1.2   WMS-22496 pagenumber by orderkey (CS01)     */  
/* 14-JUL2023  CHONGCS 1.3   WMS-22496 Fix pageno issue (CS02)           */
/*************************************************************************/    
CREATE    PROC [dbo].[isp_RPT_LP_PLISTN_030]    
(    
   @c_LoadKey       NVARCHAR(10)    
 --, @c_PreGenRptData NVARCHAR(10) = ''    
)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
   DECLARE @c_pickheaderkey  NVARCHAR(10)    
         , @n_continue       INT    
         , @c_errmsg         NVARCHAR(255)    
         , @b_success        INT    
         , @n_err            INT    
         , @c_sku            NVARCHAR(20)    
         , @n_qty            INT    
         , @c_loc            NVARCHAR(10)    
         , @c_orderkey       NVARCHAR(10)    
         , @c_OHOrderkey     NVARCHAR(10)    
         , @c_Externorderkey NVARCHAR(50)      --CS01    
         , @c_ConsigneeKey   NVARCHAR(15)    
         , @c_Company        NVARCHAR(100)     --CS01    
         , @c_Addr1          NVARCHAR(45)    
         , @c_Addr2          NVARCHAR(45)    
         , @c_Addr3          NVARCHAR(45)    
         , @c_Addr4          NVARCHAR(45)    
         , @c_PostCode       NVARCHAR(100)    
         , @c_Route          NVARCHAR(10)    
         , @c_Notes          NVARCHAR(60)    
         , @c_SkuDesc        NVARCHAR(60)    
         , @n_CaseCnt        INT    
         , @n_PalletCnt      INT    
         , @n_InnerCnt       INT    
         , @n_EachCnt        INT    
         , @c_PrintedFlag    NVARCHAR(1)    
         , @c_UOM            NVARCHAR(10)    
         , @c_PUOM3          NVARCHAR(10)    
         , @c_Lot            NVARCHAR(10)    
         , @c_StorerKey      NVARCHAR(15)    
         , @c_GetStorerKey   NVARCHAR(15)    
         , @n_PgGroup        INT    
         , @n_TotCases       INT    
         , @n_RowNo          INT    
         , @c_firstorderkey  NVARCHAR(10)    
         , @c_superorderflag NVARCHAR(1)    
         , @c_firsttime      NVARCHAR(1)    
         , @c_logicalloc     NVARCHAR(18)    
         , @c_Lottable01     NVARCHAR(18)    
         , @c_Lottable02     NVARCHAR(18)    
         , @c_Lottable03     NVARCHAR(18)    
         , @c_Lottable04     NVARCHAR(10)    
         , @c_Lottable05     NVARCHAR(10)    
         , @d_Lottable04     DATETIME    
         , @c_Lottable06     NVARCHAR(30)    
         , @c_Lottable07     NVARCHAR(30)    
         , @c_Lottable08     NVARCHAR(30)    
         , @c_Lottable09     NVARCHAR(30)    
         , @c_Lottable10     NVARCHAR(30)    
         , @d_DeliveryDate   DATETIME    
         , @c_PickDate       NVARCHAR(10)    
         , @c_loadDate       NVARCHAR(10)    
         , @c_pickslipno     NVARCHAR(10)    
         , @c_OHFacility     NVARCHAR(10)    
         , @c_RegenDataTrigger       NVARCHAR(1) = 'N'    
         , @c_PreGenRptData          NVARCHAR(10) = '' 
         , @n_NoOfLine               INT           --CS01    
         , @n_RowNum                 INT           --CS01   
         , @n_initialflag            INT = 1       --CS01
         , @n_TTLPage                INT = 1       --CS01 
         , @n_ctnord                 INT = 1       --CS01
         , @c_ChgGrp                 NVARCHAR(1) = 'N'   --CS01 
         , @n_maxRec                 INT                 --CS02
    
   DECLARE @c_PrevOrderKey NVARCHAR(10)    
         , @n_Pallets      INT    
         , @n_Cartons      INT    
         , @n_Eaches       INT    
         , @n_UOMQty       INT    
         , @n_starttcnt    INT    
    
   DECLARE @n_qtyorder     INT    
         , @n_qtyallocated INT    
    
   DECLARE @n_OrderRoute INT    
         , @n_ShowUOMQty INT    
         , @n_Pallet     FLOAT    
         , @n_InnerPack  FLOAT    
    
    
   DECLARE @c_LRoute      NVARCHAR(10)    
         , @c_LEXTLoadKey NVARCHAR(20)    
         , @c_OHPriority  NVARCHAR(10)    
         , @c_LUdef01     NVARCHAR(20)    
         , @c_Lott01title NVARCHAR(30)    
         , @c_Lott02title NVARCHAR(30)    
         , @c_Lott03title NVARCHAR(30)    
         , @c_Lott04title NVARCHAR(30)    
         , @c_Lott05title NVARCHAR(30)    
         , @c_Lott06title NVARCHAR(30)    
         , @c_Lott07title NVARCHAR(30)    
         , @c_Lott08title NVARCHAR(30)    
         , @c_Lott09title NVARCHAR(30)    
         , @c_Lott10title NVARCHAR(30)    
         , @n_ttlqty      INT 
       
    
DECLARE    @c_Type        NVARCHAR(1) = '1'                              
         , @c_DataWindow  NVARCHAR(60) = 'RPT_LP_PLISTN_030'          
         , @c_RetVal      NVARCHAR(255)         
    
    
SET @c_RetVal = ''       
SET @n_NoOfLine = 5     --CS01
    
    
      SELECT TOP 1 @c_GetStorerKey = OH.StorerKey    
      FROM dbo.ORDERS OH (NOLOCK)       
      WHERE OH.loadkey = @c_loadkey    
     
      
      IF ISNULL(@c_GetStorerKey,'') <> ''          
      BEGIN          
          
      EXEC [dbo].[isp_GetCompanyInfo]          
               @c_Storerkey  = @c_GetStorerKey          
            ,  @c_Type       = @c_Type          
            ,  @c_DataWindow = @c_DataWindow          
            ,  @c_RetVal     = @c_RetVal           OUTPUT          
           
      END      
    
      IF ISNULL(@c_PreGenRptData, '') IN ( '0' ) OR @c_PreGenRptData = ''    
      BEGIN    
         SET @c_PreGenRptData = ''    
         SET @c_RegenDataTrigger = 'N'    
      END    
      ELSE    
      BEGIN    
           SET @c_RegenDataTrigger = 'Y'    
      END    
    
   SET @n_OrderRoute = 0    
   SET @n_ShowUOMQty = 0    
   SET @n_Pallet = 0.00    
   SET @n_CaseCnt = 0.00    
   SET @n_InnerPack = 0.00    
   SET @n_PgGroup = 1    
    
   CREATE TABLE #temp_pick    
   (    
      PickSlipNo         NVARCHAR(10) NULL,        
      LoadKey            NVARCHAR(10),        
      OrderKey           NVARCHAR(10),     
      LOC                NVARCHAR(10) NULL,     
      ROUTE              NVARCHAR(10) NULL,        
    --  Route_Desc         NVARCHAR(60) NULL,    
      SKU                NVARCHAR(20),        
      SkuDesc            NVARCHAR(60),        
      Qty                INT,     
      PrintedFlag        NVARCHAR(1) NULL,      
      PgGroup            INT,        
      RowNum             INT,     
      externorderkey     NVARCHAR(50) NULL,    --CS01    
      UOM                NVARCHAR(10),     
      DeliveryDate       NVARCHAR(10) NULL,     
      OrderDate          NVARCHAR(10) NULL,       
      SKU_SIZE           NVARCHAR(30) NULL,         
      SKUMEASUREMENT     NVARCHAR(10) NULL,          
      Storerkey          NVARCHAR(15) NULL,        
      ORD_Type           NVARCHAR(10) NULL,        
      ORD_GROUP          NVARCHAR(50) NULL,        
      Style              NVARCHAR(20) NULL,     
      Lottable07         NVARCHAR(30) NULL,    
      Logo               NVARCHAR(255) NULL,    
      Company            NVARCHAR(100),          --CS01    
      Addr1              NVARCHAR(45) NULL,        
      Addr2              NVARCHAR(45) NULL,        
      Addr3              NVARCHAR(45) NULL,        
      PostCode           NVARCHAR(15) NULL,      
      Notes1             NVARCHAR(60) NULL,        
      Notes2             NVARCHAR(60) NULL,    
      Family             NVARCHAR(30) NULL,    
      Retailsku NVARCHAR(20) NULL,    
      OrdLineNo          NVARCHAR(10) NULL,    
      TTLQTY             INT,
      TTLPAGE            INT                             --CS01
   )    
    
   SELECT @n_continue = 1    
        , @n_starttcnt = @@TRANCOUNT    
    
    
   WHILE @@TRANCOUNT > 0    
   COMMIT TRAN    
    
   SELECT @n_RowNo = 0    
   SELECT @c_firstorderkey = N'N'    
    
   IF EXISTS (  SELECT 1    
                FROM PICKHEADER (NOLOCK)    
                WHERE ExternOrderKey = @c_LoadKey AND Zone = '3')    
   BEGIN    
      SELECT @c_firsttime = N'N'    
      SELECT @c_PrintedFlag = N'Y'    
   END    
   ELSE    
   BEGIN    
      SELECT @c_firsttime = N'Y'    
      SELECT @c_PrintedFlag = N'N'    
   END    
    
   BEGIN TRAN    
    
   INSERT INTO #temp_pick    
   (    
       PickSlipNo,    
       LoadKey,    
       OrderKey,    
       LOC,    
       ROUTE,    
  --     Route_Desc,    
       SKU,    
       SkuDesc,    
       Qty,    
       PrintedFlag,    
       PgGroup,    
       RowNum,    
       externorderkey,    
       UOM,    
       DeliveryDate,    
       OrderDate,    
       SKU_SIZE,    
       SKUMEASUREMENT,    
       Storerkey,    
       ORD_Type,    
       ORD_GROUP,    
       Style,    
       Lottable07,    
       Logo,    
       Company,Addr1,Addr2,Addr3,PostCode,    
       Notes1,Notes2,Family,Retailsku,OrdLineNo,TTLQTY,TTLPAGE              --CS01    
   )    
    
SELECT  (        
              SELECT PICKHEADERKEY        
              FROM   PICKHEADER WITH (NOLOCK)        
              WHERE  ExternOrderKey     = @c_LoadKey        
                     AND OrderKey       = PickDetail.OrderKey        
                     AND ZONE           = '3'        
          ),     
          @c_LoadKey                     AS LoadKey,        
          PickDetail.OrderKey,        
          PickDetail.loc,     
          ISNULL(UPPER(ORDERS.Route), '')       AS ROUTE,      
          RTRIM(UPPER(PickDetail.sku)),         
          ISNULL(Sku.Descr, '')             SkuDescr,      
          SUM(PickDetail.qty)            AS Qty,      
          ISNULL(        
              (        
                  SELECT DISTINCT 'Y'        
                  FROM   PickHeader(NOLOCK)        
                  WHERE  ExternOrderKey     = @c_Loadkey        
                         AND Zone           = '3'        
              ),        
              'N'        
          )                              AS PrintedFlag,       
          ''                            AS PgGroup,    
           (ROW_NUMBER() OVER (PARTITION BY PickDetail.OrderKey  ORDER BY 
                      PickDetail.OrderKey,PickDetail.loc, ISNULL(Sku.BUSR10, ''), ISNULL(Sku.size, ''),    
                      ISNULL(Sku.measurement, ''),  sku.style,UPPER(LotAttribute.lottable07) ))        AS RowNo,     --CS01 
          ORDERS.ExternOrderKey          AS ExternOrderKey,     
          ISNULL(OrderDetail.UOM, '')    AS UOM,      
          CONVERT(NVARCHAR(10),ORDERS.deliverydate,103) AS DeliveryDate,     
          CONVERT(NVARCHAR(10),ORDERS.OrderDate,103) AS OrderDate,     
          ISNULL(Sku.size, ''),    
          ISNULL(Sku.measurement, ''),    
          ORDERS.Storerkey,     
          ISNULL(ORDERS.type, '')       AS ohtype,     
          ISNULL(ORDERS.ordergroup, '')       AS ordgrp,     
          sku.style,    
          UPPER(LotAttribute.lottable07),    
          ISNULL(@c_Retval,'')    AS Logo,    
          ISNULL(ORDERS.c_Company, '')   AS Company,        
          ISNULL(ORDERS.C_Address1, '')  AS Addr1,        
          ISNULL(ORDERS.C_Address2, '')  AS Addr2,       
          ISNULL(ORDERS.C_Address3, '')  AS Addr3,       
          ISNULL(ORDERS.C_Zip, '')       AS PostCode ,    
          CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes, '')) Notes1,         
          CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes2, '')) Notes2,    
          ISNULL(Sku.BUSR10, ''),ISNULL(Sku.RETAILSKU, ''),pickdetail.orderlinenumber,pdet.pqty,0    
   FROM   pickdetail(NOLOCK)        
          JOIN orders(NOLOCK)        
               ON  pickdetail.orderkey = orders.orderkey        
          JOIN lotattribute(NOLOCK)        
               ON  pickdetail.lot = lotattribute.lot        
          JOIN loadplandetail(NOLOCK)        
               ON  pickdetail.orderkey = loadplandetail.orderkey        
          JOIN orderdetail(NOLOCK)    
               ON  pickdetail.orderkey = orderdetail.orderkey        
               AND pickdetail.orderlinenumber = orderdetail.orderlinenumber        
          JOIN storer(NOLOCK)        
               ON  pickdetail.storerkey = storer.storerkey        
          JOIN sku(NOLOCK)        
               ON  pickdetail.sku = sku.sku        
               AND pickdetail.storerkey = sku.storerkey        
          JOIN pack(NOLOCK)        
               ON  pickdetail.packkey = pack.packkey        
          JOIN loc(NOLOCK)        
               ON  pickdetail.loc = loc.loc      
          CROSS APPLY (SELECT pd.OrderKey AS orderkey, SUM(pd.qty) AS pqty FROM  dbo.PICKDETAIL pd WITH (NOLOCK) WHERE pd.orderkey = orders.orderkey GROUP BY pd.OrderKey ) AS pdet    
          where LoadPlanDetail.LoadKey = @c_LoadKey     
     GROUP BY                  
          PickDetail.OrderKey,        
          PickDetail.loc,     
          ISNULL(UPPER(ORDERS.Route), '') ,      
          RTRIM(UPPER(PickDetail.sku)),         
          ISNULL(Sku.Descr, ''),       
          ORDERS.ExternOrderKey,     
          ISNULL(OrderDetail.UOM, ''),      
          CONVERT(NVARCHAR(10),ORDERS.deliverydate,103),     
          CONVERT(NVARCHAR(10),ORDERS.OrderDate,103),     
          ISNULL(Sku.size, ''),    
          ISNULL(Sku.measurement, ''),    
          ORDERS.Storerkey,     
          ISNULL(ORDERS.type, '') ,     
          ISNULL(ORDERS.ordergroup, ''),     
          sku.style,    
          LotAttribute.lottable07 ,    
          ISNULL(ORDERS.c_Company, '')  ,        
          ISNULL(ORDERS.C_Address1, '') ,        
          ISNULL(ORDERS.C_Address2, '') ,      
          ISNULL(ORDERS.C_Address3, '') ,    
          CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes, '')),      
          CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes2, '')),    
          ISNULL(ORDERS.C_Zip, ''),    
          ISNULL(Sku.BUSR10, '') ,ISNULL(Sku.RETAILSKU, '')     
         ,pickdetail.orderlinenumber  ,pdet.pqty           
    
          IF EXISTS (SELECT 1    
                    FROM  #temp_pick    
                    WHERE LoadKey = @c_LoadKey     
                    AND ISNULL(RTRIM(PickSlipNo),'') = ''  ) AND  @c_RegenDataTrigger = 'N'     
         BEGIN    
             SET @c_PreGenRptData = CASE WHEN @c_PreGenRptData = '' THEN 'Y' ELSE @c_PreGenRptData END    
         END    
    
    
        IF @c_PreGenRptData <> 'Y'    
        BEGIN    
             GOTO PRINT_RPT    
        END    
     
   IF @c_PreGenRptData = 'Y'    
   BEGIN                               
           
         UPDATE PickHeader WITH (ROWLOCK)        
         SET    PickType = '1',        
               TrafficCop = NULL,        
               EditDate = GETDATE(),        
               EditWho  = SUSER_NAME()        
         WHERE  ExternOrderKey = @c_LoadKey        
               AND Zone = '3'        
               
        SELECT @n_err = @@ERROR    
            IF @n_err <> 0    
            BEGIN    
               SET @n_continue = 3    
               SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)    
                    , @n_err = 73010    
               SELECT @c_errmsg = N'NSQL' + CONVERT(NVARCHAR(5), @n_err)    
                                  + N': Update PickType Failed On Table Pickheader Table. (isp_RPT_LP_PLISTN_030)' + N' ( '    
                                  + N' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + N' ) '    
    
               GOTO QUIT_SP    
            END    
            ELSE    
            BEGIN    
               WHILE @@TRANCOUNT > 0    
               COMMIT TRAN    
            END    
   END    
    
   DECLARE pick_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT DISTINCT OrderKey,MAX(RowNum)        --CS02
   FROM #temp_pick (NOLOCK)    
   WHERE LoadKey = @c_LoadKey AND ISNULL(RTRIM(PickSlipNo),'') = ''     
   GROUP BY OrderKey    
   ORDER BY OrderKey,MAX(RowNum)               --Cs02
    
   OPEN pick_cur    
    
   SELECT @c_PrevOrderKey = N''    
    
   FETCH NEXT FROM pick_cur    
   INTO  @c_orderkey  , @n_maxRec                        --CS02  
    
   WHILE (@@FETCH_STATUS <> -1)    
   BEGIN    
    
    
      IF (@c_orderkey <> @c_PrevOrderKey) AND @c_PreGenRptData = 'Y'    
      BEGIN    
         IF NOT EXISTS (  SELECT 1    
                          FROM PICKHEADER (NOLOCK)    
                          WHERE ExternOrderKey = @c_LoadKey AND OrderKey = @c_orderkey AND Zone = '3')    
         BEGIN    
            EXECUTE nspg_GetKey 'PICKSLIP'    
                              , 9    
                              , @c_pickheaderkey OUTPUT    
                              , @b_success OUTPUT    
                              , @n_err OUTPUT    
                              , @c_errmsg OUTPUT    
    
            SELECT @c_pickheaderkey = N'P' + @c_pickheaderkey    
    
            INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)    
            VALUES (@c_pickheaderkey, @c_orderkey, @c_LoadKey, '0', '3', '')    
    
            UPDATE #temp_pick    
            SET PickSlipNo =   @c_pickheaderkey    
            WHERE LoadKey = @c_LoadKey AND OrderKey =  @c_orderkey AND ISNULL(RTRIM(PickSlipNo),'') = ''    
    
            SELECT @n_err = @@ERROR    
            IF @n_err <> 0    
            BEGIN    
               SET @n_continue = 3    
               SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)    
                    , @n_err = 73000    
               SELECT @c_errmsg = N'NSQL' + CONVERT(NVARCHAR(5), @n_err)    
                                  + N': Update Failed On Table Pickheader Table. (isp_RPT_LP_PLISTN_030)' + N' ( '    
                                  + N' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + N' ) '    
    
               GOTO QUIT_SP    
            END    
            ELSE    
            BEGIN    
               WHILE @@TRANCOUNT > 0    
               COMMIT TRAN    
            END    
    
            SELECT @c_firstorderkey = N'Y'    
         END    
         ELSE    
         BEGIN    
            SELECT TOP 1 @c_pickheaderkey = PickHeaderKey    
            FROM PICKHEADER (NOLOCK)    
            WHERE ExternOrderKey = @c_LoadKey AND Zone = '3' AND OrderKey = @c_orderkey    
                
            UPDATE #temp_pick    
            SET PickSlipNo =   @c_pickheaderkey    
            WHERE LoadKey = @c_LoadKey AND OrderKey =  @c_orderkey AND ISNULL(RTRIM(PickSlipNo),'') = ''    
    
         END    
      END    
    
          
    
      SELECT @c_PrevOrderKey = @c_orderkey    
      FETCH NEXT FROM pick_cur    
      INTO @c_orderkey   , @n_maxRec                        --CS02   
   END    
   CLOSE pick_cur    
   DEALLOCATE pick_cur    
    
  IF @c_RegenDataTrigger ='N'    
  BEGIN      
    SET @c_PreGenRptData = ''    
    GOTO PRINT_RPT    
  END      
    
    
PRINT_RPT:    

   --CS01 S
   SELECT @c_PrevOrderKey = N''
   SELECT @n_PgGroup = 1  
   SET    @n_TTLPAGE = 1
   SET    @c_ChgGrp  = 'N'
 DECLARE Page_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT OrderKey,RowNum   
   FROM #temp_pick (NOLOCK)    
   WHERE LoadKey = @c_LoadKey   
   ORDER BY OrderKey    
    
   OPEN Page_cur    
    
   FETCH NEXT FROM Page_cur    
   INTO  @c_orderkey,@n_RowNum    
    
   WHILE (@@FETCH_STATUS <> -1)    
   BEGIN    
      IF @c_PrevOrderKey = '' 
      BEGIN 
             SET @c_PrevOrderKey = @c_orderkey
      END 
    
      IF (@c_orderkey <> @c_PrevOrderKey)   
      BEGIN    
             SET  @n_PgGroup = 1 
             SET  @n_initialflag =  1
      END    

      SELECT @n_ctnord = COUNT(orderkey)
      FROM #temp_pick
      WHERE orderkey = @c_orderkey

      IF @n_RowNum%@n_NoOfLine = 0 
      BEGIN
          SET  @c_ChgGrp = 'Y' --@n_PgGroup = @n_PgGroup + 1
      END
      ELSE 
      BEGIN
          SET  @c_ChgGrp = 'N' 
      END


     IF (@n_ctnord/@n_NoOfLine) = 0
     BEGIN
         SET @n_TTLPAGE = 1
     END
     ELSE
     BEGIN
           IF @n_ctnord%@n_NoOfLine = 0
           BEGIN
                SET @n_TTLPAGE = (@n_ctnord/@n_NoOfLine) 
           END  
           ELSE
           BEGIN
                SET @n_TTLPAGE = (@n_ctnord/@n_NoOfLine) + 1
           END     
     END
 
      UPDATE #temp_pick   
      SET pgGroup = @n_PgGroup
          ,TTLPAGE = @n_TTLPAGE
      WHERE orderkey = @c_orderkey AND RowNum = @n_RowNum


     IF @c_ChgGrp = 'Y'
     BEGIN
       SET @n_PgGroup = @n_PgGroup + 1  
     END

      SELECT @c_PrevOrderKey = @c_orderkey   
      SELECT @n_initialflag = @n_initialflag + 1
 
      FETCH NEXT FROM Page_cur    
      INTO @c_orderkey ,@n_RowNum     
   END    
   CLOSE Page_cur    
   DEALLOCATE Page_cur  
   --CS01 E
    
   IF ISNULL(@c_PreGenRptData, '') = ''    
   BEGIN    
      SELECT #temp_pick.PickSlipNo    
           , #temp_pick.LoadKey    
           , #temp_pick.OrderKey    
           , #temp_pick.LOC    
           , #temp_pick.ROUTE    
           , #temp_pick.SKU    
           , #temp_pick.SkuDesc    
           , #temp_pick.Qty    
           , #temp_pick.PrintedFlag    
           , #temp_pick.PgGroup    
           , #temp_pick.RowNum    
           , #temp_pick.Externorderkey    
           , #temp_pick.uom    
           , #temp_pick.deliverydate    
           , #temp_pick.OrderDate    
           , #temp_pick.SKU_SIZE    
           , #temp_pick.SKUMEASUREMENT    
           , #temp_pick.Storerkey    
           , #temp_pick.ORD_Type    
           , #temp_pick.ORD_GROUP    
           , #temp_pick.Style    
           , #temp_pick.Lottable07    
           , #temp_pick.Logo    
           , #temp_pick.Company    
           , #temp_pick.Addr1    
           , #temp_pick.Addr2    
           , #temp_pick.Addr3    
           , #temp_pick.PostCode    
           , #temp_pick.Notes1    
           , #temp_pick.Notes2    
           , #temp_pick.Family    
           , #temp_pick.Retailsku    
           , #temp_pick.OrdLineNo    
           , #temp_pick.TTLQTY 
          ,  #temp_pick.TTLPAGE 
      FROM #temp_pick    
      ORDER BY #temp_pick.PickSlipNo    
             , #temp_pick.LOC    
            -- , #temp_pick.SKU    
             , #temp_pick.Family    
             , #temp_pick.SKU_SIZE    
             , #temp_pick.SKUMEASUREMENT    
             , #temp_pick.Style    
             , #temp_pick.PgGroup   
             , #temp_pick.Lottable07     

   END    
    
   QUIT_SP:    
    
    
      IF OBJECT_ID('tempdb..#temp_pick') IS NOT NULL    
      DROP TABLE #temp_pick    
    
   WHILE @@TRANCOUNT < @n_starttcnt    
   BEGIN TRAN    
    
    
   IF @n_continue = 3    
   BEGIN    
      SELECT @b_success = 0    
      IF @@TRANCOUNT > @n_starttcnt    
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_RPT_LP_PLISTN_030'    
      RAISERROR(@c_errmsg, 16, 1) WITH SETERROR    
      RETURN    
   END    
   ELSE    
   BEGIN    
      SELECT @b_success = 1    
      WHILE @@TRANCOUNT > @n_starttcnt    
      BEGIN    
         COMMIT TRAN    
      END    
   END    
    
END    

GO