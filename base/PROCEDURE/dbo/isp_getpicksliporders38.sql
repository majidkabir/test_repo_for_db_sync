SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/************************************************************************/    
/* Store Procedure: isp_GetPickSlipOrders38                             */    
/* Creation Date: 13-Dec-2010                                           */    
/* Copyright: IDS                                                       */    
/* Written by: NJOW                                                     */    
/*                                                                      */    
/* Purpose: Pickslip                                                    */    
/*                                                                      */    
/* Called By: r_dw_print_pickorder38                                    */    
/*                                                                      */    
/* PVCS Version: 1.1                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Ver.  Purposes                                */    
/* 2014-Mar-21  TLTING    1.1   SQL20112 Bug                            */
/* 28-Jan-2019  TLTING_ext 1.2  enlarge externorderkey field length      */
/************************************************************************/    
    
CREATE PROC [dbo].[isp_GetPickSlipOrders38] (@c_loadkey NVARCHAR(10))     
 AS    
 BEGIN    
   SET NOCOUNT ON     
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    
    DECLARE @c_pickheaderkey  NVARCHAR(10),    
      @n_continue           int,    
      @c_errmsg             NVARCHAR(255),    
      @b_success            int,    
      @n_err                int,    
      @n_pickslips_required int    
    
    CREATE TABLE #TEMP_PICK    
       ( PickSlipNo       NVARCHAR(10) NULL,    
         LoadKey          NVARCHAR(10),    
         OrderKey         NVARCHAR(10),    
         Company          NVARCHAR(45) NULL,    
         Route            NVARCHAR(10) NULL,    
         LOC              NVARCHAR(10) NULL,    
         SKU              NVARCHAR(20),    
         SkuDesc          NVARCHAR(60),    
         Qty              int,    
         PrintedFlag      NVARCHAR(1) NULL,    
         packcasecnt      int,    
         packinner        int,    
         externorderkey   NVARCHAR(50) NULL,      --tlting_ext
         LogicalLoc       NVARCHAR(18) NULL,      
         DeliveryDate     datetime NULL,      
         Storerkey        NVARCHAR(15) NULL,
         Packkey          NVARCHAR(10) NULL,
         Adddate          datetime NULL,
         Putawayzone      NVARCHAR(10) NULL)
                             
       INSERT INTO #TEMP_PICK    
            (PickSlipNo,          LoadKey,          OrderKey,         Company,    
             Route,               Loc,              Sku,              Skudesc,    
             Qty,                 PrintedFlag,      Packcasecnt,      Packinner,
             Externorderkey,      LogicalLoc,        DeliveryDate,     Storerkey,    
             Packkey,             Adddate,          Putawayzone)   
    
        SELECT DISTINCT     
        (SELECT PICKHEADERKEY FROM PICKHEADER (NOLOCK)     
            WHERE ExternOrderKey = @c_LoadKey     
            AND OrderKey = Orders.OrderKey     
            AND ZONE = '3'),     
        @c_LoadKey as LoadKey,                     
        Orders.OrderKey,                                
        STORER.Company,    
        ORDERS.Route,             
        PickDetail.loc,
        PickDetail.sku, 
        Sku.Descr,                      
        SUM(PickDetail.qty) as Qty,    
        IsNull((SELECT Distinct 'Y' FROM PickHeader (NOLOCK) WHERE ExternOrderKey = @c_LoadKey AND  Zone = '3'), 'N') AS PrintedFlag,     
        PACK.CaseCnt,     
        PACK.InnerPack,
        ORDERS.ExternOrderKey,                   
        LOC.LogicalLocation,    
        ORDERS.DeliveryDate,
        STORER.Storerkey,
        SKU.Packkey,
        Getdate(),
        LOC.Putawayzone
    FROM LOADPLANDETAIL (NOLOCK)     
    JOIN ORDERS (NOLOCK) ON (ORDERS.Orderkey = LoadPlanDetail.Orderkey)    
    LEFT JOIN Storer (NOLOCK) ON (ORDERS.ConsigneeKey = Storer.StorerKey)    
    JOIN OrderDetail (NOLOCK) ON (OrderDetail.OrderKey = ORDERS.OrderKey)     
    JOIN PickDetail (NOLOCK) ON (ORDERDETAIL.Orderkey = PICKDETAIL.Orderkey    
                                 AND ORDERDETAIL.Orderlinenumber = PICKDETAIL.Orderlinenumber)    
    JOIN Sku (NOLOCK)  ON (Sku.StorerKey = PickDetail.StorerKey AND Sku.Sku = PickDetail.Sku)    
    JOIN PACK (NOLOCK) ON (SKU.Packkey = PACK.Packkey)    
    JOIN LOC WITH (NOLOCK, INDEX (PKLOC)) ON (LOC.LOC = PICKDETAIL.LOC) 
   WHERE LoadPlanDetail.LoadKey = @c_LoadKey    
     GROUP BY Orders.OrderKey,                                
        STORER.Company,    
        ORDERS.Route,             
        PickDetail.loc,
        PickDetail.sku, 
        Sku.Descr,                      
        PACK.CaseCnt,     
        PACK.InnerPack,
        ORDERS.ExternOrderKey,                   
        LOC.LogicalLocation,    
        ORDERS.DeliveryDate,
        STORER.Storerkey,
        SKU.Packkey,
        LOC.Putawayzone
        
     BEGIN TRAN      
    
     -- Uses PickType as a Printed Flag      
     UPDATE PickHeader SET PickType = '1', TrafficCop = NULL     
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
             dbo.fnc_LTrim( dbo.fnc_RTrim( STR( CAST(@c_pickheaderkey AS int) +     
                              ( select count(distinct orderkey)     
                                from #TEMP_PICK as Rank     
                                WHERE Rank.OrderKey < #TEMP_PICK.OrderKey )     
                    ) -- str    
                    )) -- dbo.fnc_RTrim    
                 , 9)     
              , OrderKey, LoadKey, '0', '3', ''    
             FROM #TEMP_PICK WHERE PickSlipNo IS NULL    
             GROUP By LoadKey, OrderKey    
    
         UPDATE #TEMP_PICK     
         SET PickSlipNo = PICKHEADER.PickHeaderKey    
         FROM PICKHEADER (NOLOCK)    
         WHERE PICKHEADER.ExternOrderKey = #TEMP_PICK.LoadKey    
         AND   PICKHEADER.OrderKey = #TEMP_PICK.OrderKey    
         AND   PICKHEADER.Zone = '3'    
         AND   #TEMP_PICK.PickSlipNo IS NULL    
     END    
     GOTO SUCCESS    
 FAILURE:    
     DELETE FROM #TEMP_PICK    
 SUCCESS:    
     SELECT * FROM #TEMP_PICK      
     DROP Table #TEMP_PICK      
 END 

GO