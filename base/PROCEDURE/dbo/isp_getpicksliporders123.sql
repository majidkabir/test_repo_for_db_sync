SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_GetPickSlipOrders123                           */
/* Creation Date: 2021-07-21                                            */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-17531 - IDSMED Consolidated Pick List                   */
/*          Copy and modify from nsp_GetPickSlipOrders26                */
/*                                                                      */
/* Called By: r_dw_print_pickorder123                                   */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_GetPickSlipOrders123] (@c_loadkey NVARCHAR(10))
 AS
BEGIN
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET NOCOUNT ON
   
   DECLARE @c_pickheaderkey      NVARCHAR(10),
           @n_continue           INT,
           @n_starttcnt          INT,
           @c_errmsg             NVARCHAR(255),
           @b_success            INT,
           @n_err                INT,
           @c_sku                NVARCHAR(20),
           @c_SkuDescr           NVARCHAR(60),
           @c_Loc                NVARCHAR(10),
           @c_LogicalLoc         NVARCHAR(18),
           @c_LocType            NVARCHAR(10),
           @c_ID                 NVARCHAR(18), 
           @c_orderkey           NVARCHAR(10),
           @c_PickslipNo         NVARCHAR(10),
           @c_PrintedFlag        NVARCHAR(1),
           @c_PrevPickslipNo     NVARCHAR(10),
           @c_PickUOM            NVARCHAR(5),
           @c_PickZone           NVARCHAR(10),
           @c_C_Company          NVARCHAR(45), 
           @c_PickType           NVARCHAR(30),
           @c_PickDetailkey      NVARCHAR(10),
           @c_OrderLineNumber    NVARCHAR(5),
           @d_LoadDate           DATETIME,
           @c_Lottable02         NVARCHAR(18),
           @d_Lottable04         DATETIME,
           @n_Palletcnt          INT,
           @n_Cartoncnt          INT,
           @n_EA                 INT,          
           @n_TotalCarton        FLOAT,        
           @n_Pallet             INT,
           @n_Casecnt            INT,
           @n_Qty                INT,
           @n_PageNo             INT,
           @c_TotalPage          INT,
           @b_debug              INT,
           @c_WaveKey            NVARCHAR(10), 
           @c_Lottable02label    NVARCHAR(30),
           @c_Lottable04Label    NVARCHAR(30),
           @c_Storerkey          NVARCHAR(15),
           @c_Route              NVARCHAR(10), 
           @c_Consigneekey       NVARCHAR(15), 
           @c_OrderGrp           NVARCHAR(20), 
           @n_CntOrderGrp        INT,          
           @c_OrdGrpFlag         NVARCHAR(1),  
           @c_RLoadkey           NVARCHAR(20), 
           @c_TrfRoom            NVARCHAR(10), 
           @c_LEXTLoadKey        NVARCHAR(20), 
           @c_LPriority          NVARCHAR(10), 
           @c_LPuserdefDate01    DATETIME,      
           @n_innerpack          FLOAT,         
           @n_showField          INT,           
           @n_innercnt           FLOAT,
           @c_Lottable08         NVARCHAR(30),      
           @c_Lottable10         NVARCHAR(30),
           @c_Lottable12         NVARCHAR(30),
           @c_SKUGroup           NVARCHAR(10),
           @c_SKUItemClass       NVARCHAR(10)
   
   DECLARE @t_Result Table (
           Loadkey          NVARCHAR(10),
           Pickslipno       NVARCHAR(10),
           PickType         NVARCHAR(30),
           LoadingDate      DATETIME,
           PickZone         NVARCHAR(10),
           C_Company        NVARCHAR(45),   
           Loc              NVARCHAR(10),
           Logicalloc       NVARCHAR(18),
           SKU              NVARCHAR(20),
           Descr            NVARCHAR(60),
           Palletcnt        INT,
           Cartoncnt        INT,
           EA               INT,            
           TotalCarton      FLOAT,          
           ID               NVARCHAR(18),    
           Lottable02       NVARCHAR(18),
           Lottable04       DATETIME,
           ReprintFlag      NVARCHAR(1),
           PageNo           INT,
           TotalPage        INT,
           Route            NVARCHAR(10),
           Storerkey        NVARCHAR(15),
           Consigneekey     NVARCHAR(15),
           OrderGrpFlag     NVARCHAR(1), 
           OrderGrp         NVARCHAR(20),
           TrfRoom          NVARCHAR(10) NULL,
           LEXTLoadKey      NVARCHAR(20) NULL,
           LPriority        NVARCHAR(10) NULL,
           LPuserdefDate01  DATETIME, 
           rowid            INT IDENTITY(1,1),
           showfield        INT,
           InnerPack        FLOAT,
           Lottable08       NVARCHAR(30) NULL,
           Lottable10       NVARCHAR(30) NULL,
           Lottable12       NVARCHAR(30) NULL,
           SKUGROUP         NVARCHAR(10) NULL,
           itemclass        NVARCHAR(10) NULL
   )        
                            
   SELECT @n_continue = 1, @n_starttcnt=@@TRANCOUNT
   SELECT @b_Debug = 0
   
   IF EXISTS(SELECT 1 FROM PickHeader (NOLOCK) WHERE ExternOrderKey = @c_loadkey AND Zone = 'LB')
      SELECT @c_PrintedFlag = 'Y'
   ELSE
      SELECT @c_PrintedFlag = 'N'

   --BEGIN TRAN
   
   -- Uses PickType as a Printed Flag
   UPDATE PickHeader
   SET   PickType = '1',
         TrafficCop = NULL
   WHERE ExternOrderKey = @c_loadkey
   AND   Zone = 'LB'
   AND   PickType = '0'
   IF @@ERROR <> 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=73000
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Failed On Table Pickheader Table. (isp_GetPickSlipOrders123)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
   END
   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE pickslip_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT Loadplan.Loadkey
            ,LOC.LocationType
            ,Loadplan.AddDate
            ,ISNULL(RTRIM(LOC.PickZone),'')
            ,ISNULL(RTRIM(ORDERS.C_Company),'')
            ,Pickdetail.Loc
            ,LOC.LogicalLocation
            ,Pickdetail.Sku
            ,MAX(SKU.Descr)
            ,Pickdetail.ID
            ,LA.Lottable02
            ,LA.Lottable04
            ,PACK.Pallet
            ,PACK.Casecnt
            ,SUM(PickDetail.Qty)
            ,ISNULL(RTRIM(LOADPLAN.Route),'') 
            ,ORDERS.Storerkey 
            ,ORDERS.Consigneekey 
            ,CASE WHEN ISNULL(CLR.Code,'') = '' THEN 'N' ELSE 'Y' END AS showordergrp
            ,LOADPLAN.Trfroom 
            ,Loadplan.Externloadkey AS LEXTLoadKey       
            ,Loadplan.Priority AS LPriority              
            ,Loadplan.LPuserdefDate01 AS LPuserdefDate01 
            ,PACK.innerpack              
            ,LA.Lottable08     
            ,LA.Lottable10
            ,LA.Lottable12      
            ,SKU.SKUGROUP
            ,SKU.itemclass   
      FROM  Pickdetail WITH (NOLOCK)
      JOIN  ORDERS          WITH (NOLOCK) ON (PICKDETAIL.Orderkey = ORDERS.Orderkey)
      JOIN  LoadplanDetail WITH (NOLOCK) ON LoadplanDetail.Orderkey = PickDetail.Orderkey
      JOIN  Loadplan WITH (NOLOCK) ON Loadplan.Loadkey = LoadplanDetail.Loadkey
      JOIN  LOC WITH (NOLOCK) ON LOC.Loc = Pickdetail.Loc
      JOIN  SKU WITH (NOLOCK) ON SKU.Storerkey = PickDetail.Storerkey AND SKU.SKU = PickDetail.SKU
      JOIN  PACK WITH (NOLOCK) ON PACK.Packkey = SKU.Packkey
      JOIN  Lotattribute LA WITH (NOLOCK) ON LA.Lot = PickDetail.Lot
      LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (ORDERS.Storerkey = CLR.Storerkey AND CLR.Code = 'SHOWORDERGRP'                               
                                    AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_print_pickorder123' AND ISNULL(CLR.Short,'') <> 'N')
      WHERE Loadplan.Loadkey = @c_Loadkey
      AND   Pickdetail.Status < '5'
      GROUP BY Loadplan.Loadkey
            ,  LOC.LocationType
            ,  Loadplan.AddDate
            ,  ISNULL(RTRIM(LOC.PickZone),'')
            ,  ISNULL(RTRIM(ORDERS.C_Company),'')
            ,  Pickdetail.Loc
            ,  LOC.LogicalLocation
            ,  Pickdetail.Sku
            ,  Pickdetail.ID
            ,  LA.Lottable02
            ,  LA.Lottable04
            ,  PACK.Pallet
            ,  PACK.Casecnt
            ,  ISNULL(RTRIM(LOADPLAN.Route),'')  
            ,  ORDERS.Storerkey 
            ,  ORDERS.Consigneekey 
            ,  CASE WHEN ISNULL(CLR.Code,'') = '' THEN 'N' ELSE 'Y' END 
            ,  LOADPLAN.Trfroom 
            ,  Loadplan.Externloadkey                              
            ,  Loadplan.Priority                                  
            ,  Loadplan.LPuserdefDate01                            
            ,  PACK.innerpack      
            ,  LA.Lottable08     
            ,  LA.Lottable10
            ,  LA.Lottable12  
            ,  SKU.SKUGROUP
            ,  SKU.itemclass                           
      ORDER BY ISNULL(RTRIM(LOC.PickZone),''),
               LOC.LogicalLocation, Pickdetail.Loc, Pickdetail.SKU
   
      OPEN pickslip_cur
   
      FETCH NEXT FROM pickslip_cur INTO @c_Loadkey, @c_LocType, @d_LoadDate, @c_PickZone, @c_C_Company, @c_Loc, @c_LogicalLoc,
                                        @c_SKU, @c_SkuDescr, @c_ID, @c_Lottable02, @d_Lottable04, @n_Pallet, @n_Casecnt, @n_Qty, @c_Route, @c_Storerkey, @c_Consigneekey,@c_ordGrpflag, 
                                        @c_TrfRoom, 
                                        @c_LEXTLoadKey,@c_LPriority,@c_LPuserdefDate01,@n_innerpack,
                                        @c_Lottable08, @c_Lottable10, @c_Lottable12,
                                        @c_SKUGroup, @c_SKUItemClass
   
      WHILE (@@FETCH_STATUS <> -1) AND (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         SET @n_Palletcnt = 0
         SET @n_Cartoncnt = 0
         SET @n_EA        = 0      
         SET @n_TotalCarton = 0.00 
   
         SET @n_TotalCarton = CASE WHEN @n_Casecnt > 0 THEN @n_Qty / @n_Casecnt
                                   ELSE 0
                                   END
   
         IF UPPER(@c_PickZone) <> 'BULK'
         BEGIN
            SET @c_PickType = 'PICKING AREA'
         END
         ELSE
         BEGIN
            IF @n_Qty >= @n_Pallet
            BEGIN
               SET @c_PickType = 'FULL PALLET PICK'
            END
            ELSE
            BEGIN
               SET @c_PickType = 'CASE PICK'
            END
         END
   
         SET @n_Palletcnt = CASE WHEN @n_Pallet > 0 THEN @n_Qty/@n_Pallet ELSE 0 END
         SET @n_Cartoncnt = CASE WHEN @n_CaseCnt> 0 THEN (@n_Qty - (@n_Palletcnt * @n_Pallet))/@n_CaseCnt ELSE 0 END
         SET @n_EA        = @n_Qty - (@n_Palletcnt * @n_Pallet) - (@n_Cartoncnt * @n_CaseCnt)
         SET @n_innercnt = CASE WHEN @n_innerpack > 0 and @n_CaseCnt> 0 THEN ( (@n_Qty - (@n_Cartoncnt * @n_CaseCnt)) / @n_innerpack) ELSE 0 END
         
         SET @n_showField = 0
     
         SELECT @n_showfield  = CASE WHEN ISNULL(short,'0') ='Y' THEN 1 ELSE 0 END
         FROM CODELKUP WITH (NOLOCK)
         WHERE ListName = 'REPORTCFG'
         AND   Storerkey= @c_Storerkey
         AND   Long = 'r_dw_print_pickorder123'
         AND Code = 'showfield'
         AND   ISNULL(Short,'') <> 'N'

         INSERT INTO @t_Result (Loadkey, Pickslipno, PickType, LoadingDate, PickZone, Loc, LogicalLoc, SKU, Descr,
                  Palletcnt, Cartoncnt, TotalCarton, ID, Lottable02, Lottable04,
                  ReprintFlag, PageNo, TotalPage, C_Company, EA, Route, Storerkey, Consigneekey,OrderGrpFlag, TrfRoom, 
                  LEXTLoadKey,LPriority,LPuserdefDate01,showfield,InnerPack,
                  Lottable08, Lottable10, Lottable12, SKUGROUP, itemclass) 
         VALUES (@c_Loadkey, '', @c_PickType, @d_LoadDate, @c_PickZone, @c_LOC, @c_LogicalLoc, @c_SKU, @c_SkuDescr,
                 @n_Palletcnt, @n_Cartoncnt, @n_TotalCarton, @c_ID, @c_Lottable02, @d_Lottable04, @c_PrintedFlag, 0, 0,
                 @c_C_Company, @n_EA, @c_Route, @c_Storerkey, @c_Consigneekey,@c_OrdGrpFlag, @c_TrfRoom,  
                 @c_LEXTLoadKey,@c_LPriority,@c_LPuserdefDate01,@n_showField,@n_innercnt,
                 @c_Lottable08, @c_Lottable10, @c_Lottable12, @c_SKUGroup, @c_SKUItemClass) 
         
         FETCH NEXT FROM pickslip_cur INTO @c_Loadkey, @c_LocType, @d_LoadDate, @c_PickZone, @c_C_Company, @c_Loc, @c_LogicalLoc, 
                                           @c_SKU, @c_SkuDescr, @c_ID, @c_Lottable02, @d_Lottable04, @n_Pallet, @n_Casecnt, @n_Qty, @c_Route, @c_Storerkey, @c_Consigneekey,@c_ordGrpflag,
                                           @c_TrfRoom,               
                                           @c_LEXTLoadKey,@c_LPriority,@c_LPuserdefDate01,@n_innerpack,
                                           @c_Lottable08, @c_Lottable10, @c_Lottable12,
                                           @c_SKUGroup, @c_SKUItemClass
      END /* While */
   
      CLOSE pickslip_cur
      DEALLOCATE pickslip_cur
   END /* @n_Continue = 1 */

   IF @b_Debug = 1
   BEGIN
      SELECT * FROM @t_Result

      SELECT PickType, PickZone, Consigneekey
      FROM   @t_Result
      WHERE  Pickslipno = ''
      GROUP BY PickType, PickZone, Consigneekey
      ORDER BY CASE WHEN PickType = 'PICKING AREA' THEN '1'
            WHEN PickType = 'FULL PALLET PICK' THEN '2' ELSE '3' END, Consigneekey
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE PickType_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PickType, PickZone, Consigneekey
      FROM   @t_Result
      WHERE  Pickslipno = ''
      GROUP BY PickType, PickZone, Consigneekey
      ORDER BY CASE WHEN PickType = 'PICKING AREA' THEN '1'
            WHEN PickType = 'FULL PALLET PICK' THEN '2' ELSE '3' END, Consigneekey
        
      OPEN PickType_cur
   
      FETCH NEXT FROM PickType_cur INTO @c_PickType, @c_PickZone, @c_Consigneekey
   
      WHILE (@@FETCH_STATUS <> -1) AND (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         SET @c_pickheaderkey = ''
         SET @c_WaveKey = ''

         IF @c_PickZone = 'BULK'
         BEGIN
            IF @c_PickType = 'FULL PALLET PICK'
            BEGIN
               SELECT @c_pickheaderkey = PickHeaderKey
               FROM  PickHeader (NOLOCK)
               WHERE ExternOrderKey = @c_loadkey
                AND  WaveKey = RTRIM(@c_PickZone) + '_P'
                AND  Zone = 'LB'
                AND  ConsoOrderkey = @c_Consigneekey 
               
               SELECT @c_WaveKey = RTRIM(@c_PickZone) + '_P'  
            END
            ELSE
            BEGIN
               SELECT @c_pickheaderkey = PickHeaderKey
               FROM  PickHeader (NOLOCK)
               WHERE ExternOrderKey = @c_loadkey
                AND  WaveKey = RTRIM(@c_PickZone) + '_C'
                AND  Zone = 'LB'
                AND  ConsoOrderkey = @c_Consigneekey
                
               SELECT @c_WaveKey = RTRIM(@c_PickZone) + '_C'  
            END
         END
         ELSE
         BEGIN
            SELECT @c_pickheaderkey = PickHeaderKey
            FROM  PickHeader (NOLOCK)
            WHERE ExternOrderKey = @c_loadkey
             AND  WaveKey = @c_PickZone
             AND  Zone = 'LB'
             AND  ConsoOrderkey = @c_Consigneekey
            
            SELECT @c_WaveKey = RTRIM(@c_PickZone)
         END
   
         -- Only insert the First Pickslip# in PickHeader
         IF ISNULL(RTRIM(@c_pickheaderkey), '') = ''
         BEGIN
            EXECUTE nspg_GetKey
             'PICKSLIP',
             9,
             @c_pickheaderkey  OUTPUT,
             @b_success       OUTPUT,
             @n_err           OUTPUT,
             @c_errmsg        OUTPUT
         
            SELECT @c_pickheaderkey = 'P' + @c_pickheaderkey
         
            INSERT INTO PICKHEADER
            (PickHeaderKey,    OrderKey,    ExternOrderKey, PickType, Zone, TrafficCop, WaveKey, ConsoOrderkey)
            VALUES
            (@c_pickheaderkey, '',      @c_LoadKey,     '0',      'LB',  '', @c_WaveKey, @c_Consigneekey )   -- @c_PickZone)
         
            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=73001
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Failed On Table PICKHEADER. (isp_GetPickSlipOrders123)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
            END
         END
   
         IF @n_Continue = 1 OR @n_Continue = 2
         BEGIN
            UPDATE @t_Result
            SET    PickSlipno = @c_pickheaderkey
            WHERE  Pickslipno = ''
            AND    PickType = @c_PickType
            AND    PickZone = @c_PickZone
            AND    Consigneekey = @c_Consigneekey

            -- Get PickDetail records for each Pick Ticket (Picking Area / Full Pallet / Case Pick)
            DECLARECURSOR_PickDet:
            IF @c_PickType = 'PICKING AREA'
            BEGIN
               DECLARE PickDet_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PickDetail.Pickdetailkey, PickDetail.Orderkey, PickDetail.OrderLineNumber
               FROM   PickDetail WITH (NOLOCK)
               JOIN   LoadPlanDetail WITH (NOLOCK) ON LoadPlanDetail.Orderkey = PickDetail.Orderkey
               JOIN   LOC WITH (NOLOCK) ON LOC.Loc = Pickdetail.Loc
               JOIN   ORDERS WITH (NOLOCK) ON LoadPlanDetail.Orderkey = ORDERS.Orderkey
               WHERE  LoadPlanDetail.Loadkey = @c_Loadkey
               AND    (LOC.LocationType IN ('CASE','PICK','PALLET','BULK') OR ISNULL(LOC.PickZone,'')='')
               AND    LOC.PickZone = @c_PickZone
               AND    Pickdetail.Status < '5'
               AND    ORDERS.Consigneekey = @c_Consigneekey 
               ORDER BY Pickdetailkey
            END
            ELSE IF @c_PickType = 'FULL PALLET PICK'
            BEGIN
               DECLARE PickDet_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PickDetail.Pickdetailkey, PickDetail.Orderkey, PickDetail.OrderLineNumber
               FROM   PickDetail WITH (NOLOCK)
               JOIN   LoadPlanDetail WITH (NOLOCK) ON LoadPlanDetail.Orderkey = PickDetail.Orderkey
               JOIN   LotAttribute LA WITH (NOLOCK) ON LA.Lot = PickDetail.Lot
               JOIN   ORDERS WITH (NOLOCK) ON LoadPlanDetail.Orderkey = ORDERS.Orderkey 
               JOIN   @t_Result RESULT ON PickDetail.SKU = RESULT.SKU
                        AND PickDetail.Loc = RESULT.Loc
                        AND PickDetail.ID = RESULT.ID
                        AND ISNULL(LA.Lottable02,'') = ISNULL(RESULT.Lottable02,'')
                        AND ISNULL(LA.Lottable04,'') = ISNULL(RESULT.Lottable04,'')     
                        AND RESULT.Consigneekey = ORDERS.Consigneekey
               WHERE  LoadPlanDetail.Loadkey = @c_Loadkey
               AND    RESULT.PickType = 'FULL PALLET PICK'
               AND    Pickdetail.Status < '5'
               AND    ORDERS.Consigneekey = @c_Consigneekey
               ORDER BY Pickdetailkey
            END -- 'Full Pallet Pick'
            ELSE IF @c_PickType = 'CASE PICK'
            BEGIN
               DECLARE PickDet_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PickDetail.Pickdetailkey, PickDetail.Orderkey, PickDetail.OrderLineNumber
               FROM   PickDetail WITH (NOLOCK)
               JOIN   LoadPlanDetail WITH (NOLOCK) ON LoadPlanDetail.Orderkey = PickDetail.Orderkey
               JOIN   LotAttribute LA WITH (NOLOCK) ON LA.Lot = PickDetail.Lot
               JOIN   ORDERS WITH (NOLOCK) ON LoadPlanDetail.Orderkey = ORDERS.Orderkey
               JOIN   @t_Result RESULT ON PickDetail.SKU = RESULT.SKU
                        AND PickDetail.Loc = RESULT.Loc
                        AND PickDetail.ID = RESULT.ID
                        AND ISNULL(LA.Lottable02,'') = ISNULL(RESULT.Lottable02,'')
                        AND ISNULL(LA.Lottable04,'') = ISNULL(RESULT.Lottable04,'')
                        AND RESULT.Consigneekey = ORDERS.Consigneekey 
               WHERE  LoadPlanDetail.Loadkey = @c_Loadkey
               AND    RESULT.PickType = 'CASE PICK'
               AND    Pickdetail.Status < '5'
               AND    ORDERS.Consigneekey = @c_Consigneekey
               ORDER BY Pickdetailkey
            END -- 'CASE PICK'
         
            OPEN PickDet_cur
            SELECT @n_err = @@ERROR
         
            IF @n_err = 16905
            BEGIN
               CLOSE PickDet_cur
               DEALLOCATE PickDet_cur
               GOTO DECLARECURSOR_PickDet
            END
         
            IF @n_err = 16915
            BEGIN
               CLOSE PickDet_cur
               DEALLOCATE PickDet_cur
               GOTO DECLARECURSOR_PickDet
            END
         
            IF @n_err = 16916
            BEGIN
               GOTO EXIT_SP
            END
         
            FETCH NEXT FROM PickDet_cur INTO @c_Pickdetailkey, @c_Orderkey, @c_OrderLineNumber
         
            WHILE (@@FETCH_STATUS <> -1) AND (@n_continue = 1 OR @n_continue = 2)
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE Pickdetailkey = @c_PickDetailkey)
               BEGIN
                  INSERT INTO RefkeyLookup (Pickdetailkey, Pickslipno, Orderkey, OrderLineNumber, Loadkey)
                  VALUES (@c_PickDetailkey, @c_pickheaderkey, @c_OrderKey, @c_OrderLineNumber, @c_loadkey)
               
                  IF @@ERROR <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=73001
                     SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Failed On Table RefkeyLookup. (isp_GetPickSlipOrders123)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
                  END
               
                  IF (@n_continue = 1 OR @n_continue = 2)
                  BEGIN
                     UPDATE PICKDETAIL WITH (ROWLOCK)
                     SET    PickSlipNo = @c_pickheaderkey, TrafficCop = Null
                     WHERE  PickDetailkey = @c_PickDetailkey
                     IF @@ERROR <> 0
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=73001
                        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Failed On Table PICKDETAIL. (isp_GetPickSlipOrders123)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
                     END
                  END
               END
         
               FETCH NEXT FROM PickDet_cur INTO @c_Pickdetailkey, @c_Orderkey, @c_OrderLineNumber
            END
         
            CLOSE pickdet_cur
            DEALLOCATE pickdet_cur
         END -- Continue = 1
   
         FETCH NEXT FROM PickType_cur INTO @c_PickType, @c_PickZone, @c_Consigneekey
      END -- While : Get Pickslip#
      CLOSE PickType_cur
      DEALLOCATE PickType_cur
   END

   SET @c_OrderGrp = ''

   DECLARE C_OrdGrp CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT Distinct loadkey
   FROM   @t_Result
   ORDER BY loadkey

   OPEN C_OrdGrp

   FETCH NEXT FROM C_OrdGrp INTO @c_Rloadkey

   WHILE @@FETCH_STATUS <> -1
   BEGIN

      FETCH NEXT FROM C_OrdGrp INTO @c_RLoadkey

      SELECT @n_CntOrderGrp = COUNT(DISTINCT ord.ordergroup)
      FROM Orders Ord WITH (NOLOCK)
      WHERE Ord.Loadkey = @c_RLoadkey
      
      IF @n_CntOrderGrp = 1
      BEGIN
         SELECT @c_OrderGrp = Ord.OrderGroup
         FROM Orders ord WITH (NOLOCK)
         WHERE Ord.loadkey =  @c_RLoadkey 
      END
      
      UPDATE @t_Result
      SET OrderGrp = @c_OrderGrp
      WHERE loadkey = @c_RLoadkey
  
   END
   CLOSE C_OrdGrp
   DEALLOCATE C_OrdGrp

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      -- Assign Page No
      SET @c_PrevPickslipNo = ''
      SET @c_TotalPage = 0
      SET @n_PageNo = 1

      DECLARE C_PageNo CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT Distinct PickslipNo
      FROM   @t_Result
      ORDER BY PickslipNo
      OPEN C_PageNo

      FETCH NEXT FROM C_PageNo INTO @c_PickslipNo

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @c_PickslipNo <> @c_PrevPickslipNo
         BEGIN
            WHILE 1 = 1
             BEGIN
                IF NOT EXISTS (SELECT 1 FROM @t_Result
                               WHERE PickslipNo = @c_PickslipNo
                               AND   PageNo = 0)
              BEGIN
                 SET RowCount 0
                   BREAK
                END

                SET RowCount 20

                UPDATE @t_Result
                SET   PageNo = @n_PageNo
                WHERE PickslipNo = @c_PickslipNo
                AND   PageNo = 0

                SET  @n_PageNo    = @n_PageNo + 1
                SET  @c_TotalPage = @c_TotalPage + 1
                SET  RowCount 0
             END -- end while 1=1
         END

         SET @c_PrevPickslipNo = @c_PickslipNo

         FETCH NEXT FROM C_PageNo INTO @c_PickslipNo
      END

      CLOSE C_PageNo
      DEALLOCATE C_PageNo

      UPDATE @t_Result
      SET   TotalPage = @c_TotalPage
      WHERE TotalPage = 0

      SELECT TOP 1 @c_Storerkey = Storerkey
      FROM LOADPLANDETAIL (NOLOCK)
      JOIN ORDERS (NOLOCK) ON LoadPlanDetail.OrderKey = ORDERS.OrderKey
      WHERE LOADPLANDETAIL.Loadkey = @c_Loadkey
      
      SELECT @c_Lottable02label = Description
      FROM CODELKUP (NOLOCK)
      WHERE Code = 'Lottable02'
      AND Listname = 'RPTCOLHDR'
      AND Storerkey = @c_Storerkey
      
      SELECT @c_Lottable04label = Description
      FROM CODELKUP (NOLOCK)
      WHERE Code = 'Lottable04'
      AND Listname = 'RPTCOLHDR'
      AND Storerkey = @c_Storerkey

      IF ISNULL(@c_Lottable02label,'') = ''
         SET @c_Lottable02label = 'Batch No'
      
      IF ISNULL(@c_Lottable04label,'') = ''
         SET @c_Lottable04label = 'Exp Date'

      SELECT Loadkey
          ,  Pickslipno
          ,  PickType
          ,  LoadingDate
          ,  PickZone
          ,  Loc
          ,  Logicalloc
          ,  SKU
          ,  Descr
          ,  Palletcnt
          ,  Cartoncnt
          ,  TotalCarton
          ,  ID
          ,  Lottable02
          ,  Lottable04
          ,  ReprintFlag
          ,  PageNo
          ,  TotalPage
          ,  rowid
          ,  SUSER_SNAME()
          ,  @c_Lottable02label
          ,  @c_Lottable04label
          ,  C_Company
          ,  EA
          ,  Route
          ,  Storerkey
          ,  OrderGrpFlag
          ,  OrderGrp
          ,  TrfRoom
          ,  LEXTLoadKey
          ,  LPriority
          ,  LPuserdefDate01
          ,  Showfield
          ,  InnerPack
          ,  'Batch No' AS Lottable08Label
          ,  'Serial No' AS Lottable10Label
          ,  'PPN' AS Lottable12Label
          ,  Lottable08
          ,  Lottable10
          ,  Lottable12
          ,  SKUGROUP
          ,  itemclass
      FROM @t_Result
      ORDER BY PickslipNo, PageNo, RowID
   END

EXIT_SP:
  IF @n_continue=3  -- Error Occured - Process And Return
  BEGIN
     IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt
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
     EXECUTE nsp_logerror @n_err, @c_errmsg, 'Generation of Pick Slip'
     RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
  END
  ELSE
  BEGIN
     WHILE @@TRANCOUNT > @n_starttcnt
     BEGIN
        COMMIT TRAN
     END
  END
END

GO