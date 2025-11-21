SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: nsp_GetPickSlipOrders24                            */
/* Creation Date: 08-Mar-2007                                           */
/* Copyright: IDS                                                       */
/* Written by: Shong (Copy from nsp_GetPickSlipOrders19)                */
/*                                                                      */
/* Purpose: IDSCN PBCN Picklist (SOS69316)                              */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 08-Mar-2007  FKLIM         SOS69316                                  */
/* 12-Jun-2007  MaryVong      SOS78054 Add Orderkey into RefKeyLookUp   */
/* 26-Nov-2013  TLTING        Change user_name() to SUSER_SNAME()       */
/* 18-Sep-2015  CSCHONG       SOS#352276 (CS01)                         */
/************************************************************************/
 
CREATE PROC [dbo].[nsp_GetPickSlipOrders24] (@c_loadkey NVARCHAR(10))
AS
BEGIN
	 SET NOCOUNT ON
	 SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_OrderKey NVARCHAR(10),
      @c_PickSlipNo NVARCHAR(10),
      @c_PrevConsigneeKey NVARCHAR(15),
      @c_PrevLoadKey NVARCHAR(10),
      @c_PickDetailKey NVARCHAR(10), 
      @c_storerkey NVARCHAR(18),
      @c_consigneekey NVARCHAR(15),
      @b_success int,
      @n_err int,
      @c_errmsg NVARCHAR(255), 
      @n_Continue int, 
      @c_OrderLineNumber NVARCHAR(5),
      @c_WaveKey int    

   SELECT RefKeyLookup.PickSlipNo,
      PICKDETAIL.Lot,   
      PICKDETAIL.Loc, 
      PICKDETAIL.ID, 
      PickedQty=SUM(PICKDETAIL.Qty),   
      SKU.DESCR,   
      SKU.Sku,   
      SKU.STDNETWGT,   
      SKU.STDCUBE,   
      SKU.STDGROSSWGT,  
      LOTATTRIBUTE.Lottable02,   
      ORDERS.OrderKey,   
      ORDERDETAIL.LoadKey,
      ORDERDETAIL.UOM,
      ORDERS.StorerKey,   
      ORDERS.ConsigneeKey,   
      STORER.Company,   
      ORDERS.ExternOrderKey,               
      ORDERS.Route,   
      PACK.CaseCnt,       
      PACK.PackUOM1,   
      PACK.PackUOM3,     
      PACK.PackUOM4,  
      PACK.Pallet,    
      PACK.InnerPack,
      ORDERS.C_Company, 
      ORDERS.C_Address1, 
      ORDERS.C_Address2, 
      ORDERS.C_Address3,
      ORDERS.C_Address4, 
      ORDERS.PrintFlag,
      Notes=CONVERT(NVARCHAR(250),ORDERS.Notes),
      Prepared = CONVERT(NVARCHAR(10), Suser_Sname()),
      ORDERDETAIL.LoadKey as Rdd, 
      SKU.SUSR3,
      CODELKUP.Description as Principal,
      ORDERS.Facility,
      Facility.Descr as FacilityDescr,
      LOC.LogicalLocation,
      Loadplan.Route AS LRoute,                                                --(CS01)
      Loadplan.Externloadkey AS LEXTLoadKey,                                   --(CS01) 
      Loadplan.Priority AS LPriority,                                          --(CS01)
      Loadplan.LPuserdefDate01 AS LPuserdefDate01    --(CS01)   
   INTO  #RESULT
   FROM  LOC WITH (NOLOCK) JOIN PICKDETAIL WITH (NOLOCK)
      ON LOC.Loc = PICKDETAIL.Loc
   JOIN ORDERS WITH (NOLOCK)
    ON ORDERS.OrderKey = PICKDETAIL.OrderKey
   JOIN STORER WITH (NOLOCK)
      ON ORDERS.StorerKey = STORER.StorerKey
   LEFT OUTER JOIN STORER Consignee WITH (NOLOCK)
      ON Consignee.StorerKey = ORDERS.ConsigneeKey
   JOIN SKU WITH (NOLOCK)
      ON SKU.StorerKey = PICKDETAIL.Storerkey AND
         SKU.SKU = PICKDETAIL.SKU
   JOIN LOTATTRIBUTE WITH (NOLOCK)
      ON PICKDETAIL.Lot = LOTATTRIBUTE.Lot
   JOIN PACK WITH (NOLOCK) 
      ON PACK.PackKey = SKU.PackKey
   JOIN ORDERDETAIL WITH (NOLOCK)
      ON PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey AND
         PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber
   LEFT OUTER JOIN CODELKUP WITH (NOLOCK)
      ON CODELKUP.ListName = 'PRINCIPAL' AND
         CODELKUP.Code = SKU.SUSR3
   INNER JOIN FACILITY WITH (NOLOCK) 
      ON Facility.Facility = ORDERS.Facility
   LEFT OUTER JOIN RefKeyLookup WITH (NOLOCK) ON RefKeyLookup.PickDetailKey = PICKDETAIL.PickDetailKey 
   JOIN LOADPLAN WITH (NOLOCK)                     --(CS01)
      ON LOADPLAN.loadkey = ORDERDETAIL.loadkey    --(CS01)
   WHERE ORDERDETAIL.Loadkey = @c_loadkey
   GROUP BY 
      RefKeyLookup.PickSlipNo,
      PICKDETAIL.Lot,  
      PICKDETAIL.ID, 
      PICKDETAIL.Loc,   
      SKU.DESCR,   
      SKU.Sku,   
      SKU.STDNETWGT,   
      SKU.STDCUBE,   
      SKU.STDGROSSWGT,  
      LOTATTRIBUTE.Lottable02,   
      ORDERS.OrderKey,
      ORDERDETAIL.LoadKey,
      ORDERDETAIL.UOM,
      ORDERS.StorerKey,   
      ORDERS.ConsigneeKey,   
      STORER.Company,    
      ORDERS.ExternOrderKey,               
      ORDERS.Route,   
      PACK.CaseCnt,       
      PACK.PackUOM1,   
      PACK.PackUOM3,   
      PACK.PackUOM4,  
      PACK.Pallet,  
      PACK.InnerPack,
      ORDERS.C_Company, 
      ORDERS.C_Address1,
      ORDERS.C_Address2, 
      ORDERS.C_Address3, 
      ORDERS.C_Address4, 
      ORDERS.PrintFlag,
      CONVERT(NVARCHAR(250),ORDERS.Notes),
      SKU.SUSR3,
      CODELKUP.Description,
      ORDERS.Facility, 
      Facility.Descr, 
      LOC.LogicalLocation, -- All pick list must sort by LogicalLocation
      Loadplan.Route ,                                             --(CS01)
      Loadplan.Externloadkey ,                                      --(CS01) 
      Loadplan.Priority ,                                           --(CS01)
      Loadplan.LPuserdefDate01        --(CS01)   
   ORDER BY
      LOC.logicallocation,
      PICKDETAIL.loc,
      SKU.SKU,
      LOTATTRIBUTE.Lottable02
      -- process PickSlipNo
   
   DECLARE C_LoadKey_ExternOrdKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT DISTINCT LoadKey, ConsigneeKey 
   FROM   #RESULT 
   WHERE  PickSlipNo IS NULL OR PickSlipNo = ''
   ORDER BY LoadKey, ConsigneeKey 

   SET @c_LoadKey = ''
   SET @c_OrderKey = ''
   SET @c_ConsigneeKey=''
   SET @c_PickDetailKey = ''
   SET @n_Continue = 1 

   OPEN C_LoadKey_ExternOrdKey 

   FETCH NEXT FROM C_LoadKey_ExternOrdKey INTO @c_LoadKey, @c_ConsigneeKey   

   WHILE (@@Fetch_Status <> -1)
   BEGIN -- while 1

      IF @c_PrevLoadKey <> @c_LoadKey OR 
         @c_PrevConsigneeKey <> @c_ConsigneeKey 
      BEGIN     
         SET @c_PickSlipNo = ''

         SELECT @c_PickSlipNo = PICKHEADERKEY
         FROM PICKHEADER WITH (NOLOCK) 
         WHERE ExternOrderKey = @c_LoadKey
         AND   ConsigneeKey = @c_ConsigneeKey 
         AND   Zone = 'LB'

         IF @c_PickSlipNo IS NULL OR @c_PickSlipNo = ''  
         BEGIN   
            SELECT @c_WaveKey = MAX(WaveKey) 
            FROM PICKHEADER WITH (NOLOCK) 
            WHERE ExternOrderKey = @c_LoadKey 
            AND   ConsigneeKey = @c_ConsigneeKey

            IF @c_WaveKey IS NULL OR @c_WaveKey = '' 
            BEGIN
               SET @c_waveKey = 0 + 1
            END
            ELSE
            BEGIN
               SET @c_WaveKey = @c_WaveKey + 1
            END
            
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

               INSERT PICKHEADER (pickheaderkey, externOrderKey, WaveKey, ConsigneeKey, Zone)
               VALUES (@c_PickSlipNo, @c_loadkey, @c_WaveKey, @c_ConsigneeKey, 'LB')

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
            SELECT PickDetail.PickDetailKey, PickDetail.OrderKey, PickDetail.OrderLineNumber --SOS78054  
            FROM   PickDetail WITH (NOLOCK)
            JOIN   OrderDetail WITH (NOLOCK) ON PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey AND
                                            PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber 
            JOIN ORDERS WITH (NOLOCK) ON ORDERS.OrderKey = PICKDETAIL.OrderKey
            WHERE OrderDetail.LoadKey  = @c_LoadKey 
               AND Orders.ConsigneeKey = @c_ConsigneeKey
            ORDER BY PickDetail.PickDetailKey 

            OPEN C_PickDetailKey

            FETCH NEXT FROM C_PickDetailKey INTO @c_PickDetailKey, @c_OrderKey, @c_OrderLineNumber 

            WHILE @@FETCH_STATUS <> -1
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @c_PickDetailKey) 
               BEGIN 
                  INSERT INTO RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey) --SOS78054 
                  VALUES (@c_PickDetailKey, @c_PickSlipNo, @c_OrderKey, @c_OrderLineNumber, @c_LoadKey)                      
               END 

               FETCH NEXT FROM C_PickDetailKey INTO @c_PickDetailKey, @c_OrderKey, @c_OrderLineNumber 
            END 
            CLOSE C_PickDetailKey 
            DEALLOCATE C_PickDetailKey 
         END       
      END -- @c_PrevLoadKey <> @c_LoadKey 

      UPDATE #RESULT
      SET PickSlipNo = @c_PickSlipNo
      WHERE LoadKey = @c_LoadKey 
      AND   ConsigneeKey = @c_ConsigneeKey   
      AND   (PickSlipNo IS NULL OR PickSlipNo = '')

      IF @c_PrevConsigneeKey <> @c_ConsigneeKey
      BEGIN 
         -- update print flag
         UPDATE ORDERS
         SET TrafficCop = NULL,
             PrintFlag = 'Y'
         WHERE LoadKey = @c_LoadKey
         AND   ConsigneeKey = @c_ConsigneeKey
      END

      SET @c_PrevLoadKey = @c_LoadKey 
      SET @c_PrevConsigneeKey = @c_ConsigneeKey

      FETCH NEXT FROM C_LoadKey_ExternOrdKey INTO @c_LoadKey, @c_ConsigneeKey  
   END -- while 1 

   CLOSE C_LoadKey_ExternOrdKey
   DEALLOCATE C_LoadKey_ExternOrdKey 
   
   IF @n_Continue = 1 
   BEGIN
      -- return result set
      SELECT 
         PickSlipNo,           Lot,                     Loc,           ID,
         SUM(PickedQty) as PickedQty,  DESCR,           Sku,           STDNETWGT,  
         STDCUBE,              STDGROSSWGT,             Lottable02,    MAX(OrderKey) as OrderKey, 
         LoadKey,              UOM,                     StorerKey,     ConsigneeKey,    
         Company,              MAX(ExternOrderKey) as ExternOrderKey,  Route,       CaseCnt,
         PackUOM1,             PackUOM3,                PackUOM4,      Pallet,
         InnerPack,            C_Company,               C_Address1,    C_Address2,
         C_Address3,           C_Address4,              PrintFlag,     Notes,
         Prepared,             Rdd,                     Susr3,         Principal,
         Facility,             FacilityDescr,           LogicalLocation,
         LRoute,LEXTLoadKey,LPriority,LPuserdefDate01                         --(CS01)
      FROM #RESULT 
      GROUP BY 
         PickSlipNo,           Lot,                     Loc,           ID,
         DESCR,                Sku,                     STDNETWGT,  
         STDCUBE,              STDGROSSWGT,             Lottable02,    
         LoadKey,              UOM,                     StorerKey,     ConsigneeKey,    
         Company,              Route,                   CaseCnt,
         PackUOM1,             PackUOM3,                PackUOM4,      Pallet,
         InnerPack,            C_Company,               C_Address1,    C_Address2,
         C_Address3,           C_Address4,              PrintFlag,     Notes,
         Prepared,             Rdd,                     Susr3,         Principal,
         Facility,             FacilityDescr,           LogicalLocation,
         LRoute,LEXTLoadKey,LPriority,LPuserdefDate01                         --(CS01)
      ORDER BY PickSlipNo 
   END 

   -- drop table
   DROP TABLE #RESULT 

END

GO