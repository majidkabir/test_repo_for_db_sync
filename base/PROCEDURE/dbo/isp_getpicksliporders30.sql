SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_GetPickSlipOrders30                            */
/* Creation Date: 2009-09-23                                            */
/* Copyright: IDS                                                       */
/* Written by: NJOW (modified from nsp_GetPickSlipOrders27)             */
/*                                                                      */
/* Purpose:  Pickslip for NIVEA                                         */
/*                                                                      */
/* Input Parameters:  @c_loadkey  - Loadkey                             */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_print_pickorder30                  */
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
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length     */
/* 14-Apr-2020  CSCHONG    1.2  WMS-12759 add report config (CS01)      */
/************************************************************************/

CREATE PROC [dbo].[isp_GetPickSlipOrders30] (@c_loadkey NVARCHAR(10)) 
AS
BEGIN
    SET NOCOUNT ON         
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF


   DECLARE @c_pickheaderkey NVARCHAR(10),
      @n_continue         int,
      @c_errmsg           NVARCHAR(255),
      @b_success          int,
      @n_err              int,
      @n_pickslips_required int
                           

      CREATE TABLE #TEMP_PICK
      ( PickSlipNo       NVARCHAR(10) NULL,
         LoadKey          NVARCHAR(10),
         OrderKey         NVARCHAR(10),
         ConsigneeKey     NVARCHAR(15),
         Company          NVARCHAR(45),
         Addr1            NVARCHAR(45) NULL,
         Addr2            NVARCHAR(45) NULL,
         Addr3            NVARCHAR(45) NULL,
         Route            NVARCHAR(10) NULL,
         LOC              NVARCHAR(10) NULL, 
         SKU              NVARCHAR(20),
         SkuDesc          NVARCHAR(60),
         Qty              int,
         PrintedFlag      NVARCHAR(1) NULL,
         Lottable02       NVARCHAR(18) NULL,     
         Lottable04       datetime NULL,
         packcasecnt      int, 
         externorderkey   NVARCHAR(50) NULL,   --tlting_ext
         LogicalLoc       NVARCHAR(18) NULL,  
         facility         NVARCHAR(5) NULL,
         adddate          datetime NULL,
         putawayzone      NVARCHAR(10) NULL,
         RPTTITLE         NVARCHAR(150) NULL )   --CS01

      INSERT INTO #TEMP_PICK
         ( PickSlipNo,          LoadKey,         OrderKey,        ConsigneeKey,
            Company,             Addr1,           Addr2,          
            Addr3,               Route,            
            LOC,                SKU,
            SkuDesc,             Qty,                 PrintedFlag,     
            Lottable02,          Lottable04,
            packcasecnt,         externorderkey,  LogicalLoc,                            
            Facility,            adddate,         putawayzone , RPTTITLE )     --CS01
      SELECT
            (  SELECT PICKHEADERKEY FROM PICKHEADER WITH (NOLOCK)
               WHERE ExternOrderKey = @c_LoadKey 
               AND OrderKey = PickDetail.OrderKey 
               AND ZONE = '3'),
            @c_LoadKey as LoadKey,                 
            PickDetail.OrderKey,                            
            ISNULL(ORDERS.ConsigneeKey, '') AS ConsigneeKey,  
            ISNULL(ORDERS.c_Company, '')    AS Company,   
            ISNULL(ORDERS.C_Address1,'')    AS Addr1,            
            ISNULL(ORDERS.C_Address2,'')    AS Addr2,
            ISNULL(ORDERS.C_Address3,'') AS Addr3,            
            ORDERS.Route,         
            PickDetail.loc,   
            PickDetail.sku,                         
            ISNULL(Sku.Descr,'') AS SkuDescr,                  
            SUM(PickDetail.qty)  AS Qty,
            ISNULL((SELECT Distinct 'Y' FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @c_Loadkey AND  Zone = '3')
                   , 'N') AS PrintedFlag, 
            LotAttribute.Lottable02,                
            ISNULL(LotAttribute.Lottable04, '19000101') Lottable04,        
            PACK.CaseCnt,
            ORDERS.ExternOrderKey,               
            LOC.LogicalLocation, 
            Loadplan.facility,
            Loadplan.adddate,
            Loc.putawayzone,
            CASE WHEN ISNULL(C.short,'') = 'Y' THEN C1.notes ELSE 'NIVEA Picking Slip' END AS Rpttitle   --CS01
       FROM Loadplan WITH (NOLOCK)
       JOIN loadplandetail WITH (NOLOCK) ON loadplan.loadkey = loadplandetail.loadkey
       JOIN ORDERS         WITH (NOLOCK) ON loadplandetail.orderkey = orders.orderkey
       JOIN orderdetail    WITH (NOLOCK) ON orders.orderkey = orderdetail.orderkey
       JOIN pickdetail     WITH (NOLOCK) ON orderdetail.orderkey = pickdetail.orderkey
                                           AND orderdetail.orderlinenumber = pickdetail.orderlinenumber      
       JOIN lotattribute   WITH (NOLOCK) ON pickdetail.lot = lotattribute.lot
       JOIN storer         WITH (NOLOCK) ON pickdetail.storerkey = storer.storerkey
       JOIN sku            WITH (NOLOCK) ON pickdetail.sku = sku.sku and pickdetail.storerkey = sku.storerkey
       JOIN pack           WITH (NOLOCK) ON sku.packkey = pack.packkey
       JOIN loc            WITH (NOLOCK) ON pickdetail.loc = loc.loc
       LEFT JOIN Codelkup C WITH (NOLOCK) ON C.listname = 'REPORTCFG' and C.code='SHOWRPTTITLE' AND C.Storerkey = ORDERS.StorerKey
                                             AND C.Long = 'r_dw_print_pickorder30' AND ISNULL(C.Short,'') <> 'N'
       LEFT JOIN Codelkup C1 WITH (NOLOCK) ON C1.listname = 'PLNTITLE' AND C1.notes2 = 'r_dw_print_pickorder30' 
                                            AND C1.Storerkey = ORDERS.StorerKey
       WHERE PickDetail.Status < '5'  
        AND LoadPlan.LoadKey = @c_LoadKey
       GROUP BY PickDetail.OrderKey,                            
            ISNULL(ORDERS.ConsigneeKey, ''),  
            ISNULL(ORDERS.c_Company, ''),   
            ISNULL(ORDERS.C_Address1,''),            
            ISNULL(ORDERS.C_Address2,''),
            ISNULL(ORDERS.C_Address3,''),            
            ORDERS.Route,         
            PickDetail.loc,   
            PickDetail.sku,                         
            ISNULL(Sku.Descr,''),                  
            LotAttribute.Lottable02,                
            LotAttribute.Lottable04,        
            PACK.CaseCnt,
            ORDERS.ExternOrderKey,
            LOC.LogicalLocation, 
            Loadplan.facility,
            Loadplan.adddate,
            Loc.putawayzone
            ,CASE WHEN ISNULL(C.short,'') = 'Y' THEN C1.notes ELSE 'NIVEA Picking Slip' END       --CS01 
   
      BEGIN TRAN  
      -- Uses PickType as a Printed Flag  
      
      UPDATE PickHeader WITH (ROWLOCK) SET PickType = '1', TrafficCop = NULL 
      WHERE ExternOrderKey = @c_LoadKey AND Zone = '3' 

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
    SELECT orderkey, SUM(openqty) AS totopenqty, SUM(qtyallocated) AS totqtyallocated
    INTO #TEMP_ORD
    FROM ORDERDETAIL (NOLOCK)
    WHERE orderkey IN (SELECT orderkey FROM #TEMP_PICK)
    GROUP BY Orderkey

    SELECT TP.*, TOR.totopenqty, TOR.totqtyallocated
    FROM #TEMP_PICK TP 
    JOIN #TEMP_ORD TOR ON (TP.Orderkey = TOR.Orderkey)

     DROP Table #TEMP_PICK
     DROP Table #TEMP_ORD
END

GO