SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/************************************************************************/    
/* Store Procedure: isp_GetPickSlipWave09                               */    
/* Creation Date: 19-May-2011                                           */    
/* Copyright: IDS                                                       */    
/* Written by: NJOW                                                     */    
/*                                                                      */    
/* Purpose: Pickslip SOS#208276                                         */    
/*                                                                      */    
/* Called By: r_dw_print_wave_pickslip_09                               */    
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
/************************************************************************/    
    
CREATE PROC [dbo].[isp_GetPickSlipWave09] (@c_wavekey NVARCHAR(10))     
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
         WaveKey          NVARCHAR(10),    
         --OrderKey         NVARCHAR(10),    
         Company          NVARCHAR(45) NULL,    
         Route            NVARCHAR(10) NULL,    
         LOC              NVARCHAR(10) NULL,    
         SKU              NVARCHAR(20),    
         SkuDesc          NVARCHAR(60),    
         Qty              int,    
         PrintedFlag      NVARCHAR(1) NULL,    
         packcasecnt      int,    
         packinner        int,    
         --externorderkey   NVARCHAR(30) NULL,    
         LogicalLoc       NVARCHAR(18) NULL,      
         DeliveryDate     datetime NULL,      
         --Storerkey        NVARCHAR(15) NULL,
         Packkey          NVARCHAR(10) NULL,
         Adddate          datetime NULL,
         Putawayzone      NVARCHAR(10) NULL,
         Consigneekey     NVARCHAR(15) NULL,
         Loadkey          NVARCHAR(10) NULL)
                             
       INSERT INTO #TEMP_PICK    
            (PickSlipNo,          WaveKey,          Company,    
             Route,               Loc,              Sku,              Skudesc,    
             Qty,                 PrintedFlag,      Packcasecnt,      Packinner,
             LogicalLoc,       DeliveryDate,         
             Packkey,             Adddate,          Putawayzone,			Consigneekey,		Loadkey )   
    
        SELECT DISTINCT     
        (SELECT PICKHEADERKEY FROM PICKHEADER (NOLOCK)     
            WHERE Wavekey = @c_wavekey
            AND ExternOrderKey = Orders.Consigneekey     
            AND ZONE = '7'),     
        @c_Wavekey as WaveKey,                     
        --Orders.OrderKey,                                
        STORER.Company,    
        ORDERS.Route,             
        PickDetail.loc,
        PickDetail.sku, 
        Sku.Descr,                      
        SUM(PickDetail.qty) as Qty,    
        IsNull((SELECT Distinct 'Y' FROM PickHeader (NOLOCK) WHERE Wavekey = @c_Wavekey AND ExternOrderKey = Orders.Consigneekey AND  Zone = '7'), 'N') AS PrintedFlag,     
        PACK.CaseCnt,     
        PACK.InnerPack,
        --ORDERS.ExternOrderKey,                   
        LOC.LogicalLocation,    
        MIN(ORDERS.DeliveryDate) as DeliveryDate,
        --STORER.Storerkey,
        SKU.Packkey,
        Getdate(),
        LOC.Putawayzone,
        ISNULL(Orders.Consigneekey,'') AS Consigneekey,
				MAX(ISNULL(Orders.Loadkey,'')) AS Loadkey
    FROM WAVEDETAIL (NOLOCK)     
    JOIN ORDERS (NOLOCK) ON (ORDERS.Orderkey = WaveDetail.Orderkey)    
    LEFT JOIN Storer (NOLOCK) ON (ORDERS.ConsigneeKey = Storer.StorerKey)    
    JOIN OrderDetail (NOLOCK) ON (OrderDetail.OrderKey = ORDERS.OrderKey)     
    JOIN PickDetail (NOLOCK) ON (ORDERDETAIL.Orderkey = PICKDETAIL.Orderkey    
                                 AND ORDERDETAIL.Orderlinenumber = PICKDETAIL.Orderlinenumber)    
    JOIN Sku (NOLOCK)  ON (Sku.StorerKey = PickDetail.StorerKey AND Sku.Sku = PickDetail.Sku)    
    JOIN PACK (NOLOCK) ON (SKU.Packkey = PACK.Packkey)    
    JOIN LOC with (NOLOCK, INDEX (PKLOC)) ON (LOC.LOC = PICKDETAIL.LOC) 
   WHERE WaveDetail.WaveKey = @c_WaveKey    
     GROUP BY --Orders.OrderKey,                                
        STORER.Company,    
        ORDERS.Route,             
        PickDetail.loc,
        PickDetail.sku, 
        Sku.Descr,                      
        PACK.CaseCnt,     
        PACK.InnerPack,
        --ORDERS.ExternOrderKey,                   
        LOC.LogicalLocation,    
        --ORDERS.DeliveryDate,
        --STORER.Storerkey,
        SKU.Packkey,
        LOC.Putawayzone,
	      Orders.Consigneekey
        
     BEGIN TRAN      
    
     -- Uses PickType as a Printed Flag      
     UPDATE PickHeader SET PickType = '1', TrafficCop = NULL     
     WHERE Wavekey = @c_Wavekey
     AND Zone = '7'     
    
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
    
     SELECT @n_pickslips_required = Count(DISTINCT Consigneekey)     
     FROM #TEMP_PICK    
     WHERE PickSlipNo IS NULL    
     IF @@ERROR <> 0    
     BEGIN    
         GOTO FAILURE    
     END    
     ELSE IF @n_pickslips_required > 0    
     BEGIN    
         EXECUTE nspg_GetKey 'PICKSLIP', 9, @c_pickheaderkey OUTPUT, @b_success OUTPUT, @n_err  OUTPUT, @c_errmsg OUTPUT, 0, @n_pickslips_required    
         INSERT INTO PICKHEADER (PickHeaderKey, WaveKey, ExternOrderKey, PickType, Zone, TrafficCop)    
             SELECT 'P' + RIGHT ( REPLICATE ('0', 9) +     
             dbo.fnc_LTrim( dbo.fnc_RTrim( STR( CAST(@c_pickheaderkey AS int) +     
                              ( select count(distinct consigneekey)     
                                from #TEMP_PICK as Rank     
                                WHERE Rank.ConsigneeKey < #TEMP_PICK.ConsigneeKey )     
                    ) -- str    
                    )) -- dbo.fnc_RTrim    
                 , 9)     
              , WaveKey, ConsigneeKey, '0', '7', ''    
             FROM #TEMP_PICK WHERE PickSlipNo IS NULL    
             GROUP By WaveKey, ConsigneeKey    
    
         UPDATE #TEMP_PICK     
         SET PickSlipNo = PICKHEADER.PickHeaderKey    
         FROM PICKHEADER (NOLOCK)    
         WHERE PICKHEADER.WaveKey = #TEMP_PICK.WaveKey
         AND   PICKHEADER.ConsigneeKey = #TEMP_PICK.ConsigneeKey    
         AND   PICKHEADER.Zone = '7'    
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