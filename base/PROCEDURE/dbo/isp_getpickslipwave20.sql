SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_GetPickSlipWave20                              */
/* Creation Date:  10-MAY-2020                                          */
/* Copyright: IDS                                                       */
/* Written by:  CSCHONG                                                 */
/*                                                                      */
/* Purpose:  WMS-17281 CN PUMA Pickslip Report CR                       */
/*                                                                      */
/* Input Parameters:  @a_s_LoadKey  - (LoadKey)                         */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  Report                                               */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: r_dw_print_wave_pickslip_20_main                          */                                                        
/*           copy from r_dw_consolidated_pick19_2                       */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 18-Jun-2020  CSCHONG   1.1   Fix recgrp sorting (CS01)               */
/* 01-Jul-2020  CSCHONG   1.2   WMS-14015 revised field mapping (CS02)  */
/************************************************************************/

CREATE PROC [dbo].[isp_GetPickSlipWave20] (@a_s_LoadKey NVARCHAR(10) )
 AS
 BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @c_CurrOrderKey  NVARCHAR(10),
            @n_err           int,
            @n_continue      int,
            @c_PickHeaderKey NVARCHAR(10),
            @b_success       int,
            @c_errmsg        NVARCHAR(255),
            @n_StartTranCnt  int,
            @c_ShowTotal     NVARCHAR(1),
            @c_Storerkey     NVARCHAR(30),
            @n_MaxLine       INT = 38,
            @C_RECGROUP      NVARCHAR(20),
            @n_qty           INT = 0  

   SET @n_StartTranCnt=@@TRANCOUNT
   SET @n_continue = 1

   CREATE TABLE #TEMPWAVCONSO20(
   loadkey           NVARCHAR(10),
   pickslipno        NVARCHAR(18),
   route             NVARCHAR(10),
   adddate           DATETIME,
   loc               NVARCHAR(10),
   sku               NVARCHAR(20),
   QTY               INT,               
   sku_descr         NVARCHAR(60),
   casecnt           FLOAT,
   packkey           NVARCHAR(10),
   totalqtyordered   INT,
   totalqtyalloc     INT,
   uom3              NVARCHAR(10),
   prepackindicator  NVARCHAR(30),
   packqtyindicator  INT,
   size              NVARCHAR(10),
   locationtype      NVARCHAR(10),
   busr6             NVARCHAR(30),
   logicallocation   NVARCHAR(18),
   layout            NVARCHAR(1),
   showtotal         NVARCHAR(1),
   recgroup          INT,                  --(CS01)
   locRoom           NVARCHAR(30),
   locGrp            NVARCHAR(30),
   LPickZone         NVARCHAR(20)
   )

   CREATE TABLE #TEMPWAVCONSO20_1(
   loadkey           NVARCHAR(10),
   pickslipno        NVARCHAR(18),
   route             NVARCHAR(10),
   adddate           DATETIME,
   loc               NVARCHAR(10),
   sku               NVARCHAR(20),
   QTY               INT,               
   sku_descr         NVARCHAR(60),
   casecnt           FLOAT,
   packkey           NVARCHAR(10),
   totalqtyordered   INT,
   totalqtyalloc     INT,
   uom3              NVARCHAR(10),
   prepackindicator  NVARCHAR(30),
   packqtyindicator  INT,
   size              NVARCHAR(10),
   locationtype      NVARCHAR(10),
   busr6             NVARCHAR(30),
   logicallocation   NVARCHAR(18),
   layout            NVARCHAR(1),
   showtotal         NVARCHAR(1),
   recgroup          INT,                      --CS01
   locRoom           NVARCHAR(30),
   locGrp            NVARCHAR(30),
   LPickZone         NVARCHAR(20)
   )

 /* Start Modification */
    -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 7 - Consolidated pick list , 8 - By Order
   SET @c_PickHeaderKey = ''

   IF NOT EXISTS(SELECT PickHeaderKey 
                   FROM PICKHEADER WITH (NOLOCK) 
                  WHERE ExternOrderKey = @a_s_LoadKey 
                    AND  Zone = '5')                                    --CS02 
   BEGIN
      SET @b_success = 0

      EXECUTE nspg_GetKey
         'PICKSLIP',
         9,   
         @c_PickHeaderKey    OUTPUT,
         @b_success      OUTPUT,
         @n_err    OUTPUT,
         @c_errmsg       OUTPUT

      IF @b_success <> 1
      BEGIN
         SET @n_continue = 3
      END

      IF @n_continue = 1 or @n_continue = 2
      BEGIN
         SET @c_PickHeaderKey = 'P' + @c_PickHeaderKey

         INSERT INTO PICKHEADER (PickHeaderKey,  ExternOrderKey, PickType, Zone)
         VALUES (@c_PickHeaderKey, @a_s_LoadKey, '1', '5')                                --CS02
          
         SET @n_err = @@ERROR
   
         IF @n_err <> 0 
         BEGIN
            SET @n_continue = 3
            SET @n_err = 63501
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into PICKHEADER Failed. (isp_GetPickSlipWave20)'
         END
      END -- @n_continue = 1 or @n_continue = 2
   END
ELSE
   BEGIN
        SELECT @c_PickHeaderKey = PickHeaderKey
        FROM PickHeader WITH (NOLOCK)  
        WHERE ExternOrderKey = @a_s_LoadKey 
        AND Zone = '5'
   END

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @c_Storerkey = Orders.Storerkey
      FROM ORDERS (NOLOCK)
      WHERE ORDERS.LOADKEY = @a_s_LoadKey

      SELECT @c_ShowTotal = UPPER(SHORT)
      FROM CODELKUP (NOLOCK) 
      WHERE STORERKEY = @c_Storerkey AND LISTNAME = 'REPORTCFG' 
      AND CODE = 'SHOWTOTAL' AND LONG = 'r_dw_print_wave_pickslip_20'
   END

   IF @n_continue = 1 or @n_continue = 2
   BEGIN

      DECLARE @n_TotalQtyOrdered   INT,
              @n_TotalQtyAllocated INT

      SET @n_TotalQtyOrdered = 0
      SET @n_TotalQtyAllocated = 0 
                    
      SELECT @n_TotalQtyOrdered= SUM(OpenQty), 
             @n_TotalQtyAllocated = SUM(QtyAllocated+QtyPicked+ShippedQty) 
      FROM ORDERDETAIL WITH (NOLOCK) 
      JOIN LOADPLANDETAIL lpd (NOLOCK) ON lpd.OrderKey = ORDERDETAIL.OrderKey
      WHERE lpd.LoadKey = @a_s_LoadKey 
      GROUP BY lpd.LoadKey
      
      INSERT INTO #TEMPWAVCONSO20 
      SELECT   LoadPlanDetail.LoadKey,   
               PICKHeader.PickHeaderKey,   
               ISNULL(LoadPlan.Route,''),   
               LoadPlan.AddDate,   
               PICKDETAIL.Loc,   
               PICKDETAIL.Sku,   
               SUM(PICKDETAIL.Qty) AS Qty,  
               ISNULL(SKU.DESCR,''),   
               PACK.CaseCnt,  
               PACK.PackKey,
               @n_TotalQtyOrdered, 
               @n_TotalQtyAllocated, 
               Pack.PackUOM3 As UOM3, 
               ISNULL(LTRIM(RTRIM(SKU.PrePackIndicator)),'') As PrePackIndicator, 
               (SKU.PackQtyIndicator) As PackQtyIndicator,
               SKU.Size,
               --CASE WHEN LOC.LocationType <> 'PICK'              --CS02  START
               --     THEN 'BULK' 
               --     ELSE 'PICK'
               --     END AS LocationType,
              CASE WHEN LOC.LocationType='OTHER' THEN '0'
                            WHEN  LOC.LocationType='PICK' THEN '1'
                            WHEN LOC.LocationType='DYNPPICK' THEN '2'
              ELSE LOC.LocationType END AS LocationType,
              --CS02 END  
              ISNULL(SKU.Busr6,''), 
              CASE WHEN ISNULL(CLR.CODE,'') <> '' THEN
                  LOC.LogicalLocation ELSE LOC.Loc END, 
            CASE WHEN CLR1.Code IS NOT NULL THEN '1' ELSE '0' END as layout 
            ,ISNULL(@c_ShowTotal,'N')  
            ,'1'   
            ,LOC.locationRoom
            , '',''           
            --,Loc.locationGroup
            --,LOC.PickZone
      FROM LOADPLAN WITH (NOLOCK) 
      INNER JOIN LoadPlanDetail WITH (NOLOCK) 
              ON ( LOADPLAN.LoadKey = LoadPlanDetail.LoadKey ) 
      INNER JOIN PICKDETAIL WITH (NOLOCK) 
              ON (LoadPlanDetail.OrderKey = PICKDETAIL.OrderKey) 
      INNER JOIN SKU WITH (NOLOCK) 
              ON (SKU.StorerKey = PICKDETAIL.Storerkey ) 
             AND (SKU.Sku = PICKDETAIL.Sku )
      INNER JOIN PACK WITH (NOLOCK) 
              ON ( PACK.PackKey = SKU.PACKKey )    
      INNER JOIN PICKHEADER 
              ON (PICKHEADER.ExternOrderKey = LOADPLAN.LoadKey) 
      INNER JOIN LOT WITH (NOLOCK) 
              ON (PICKDETAIL.LOT = LOT.LOT)
      INNER JOIN SKUxLOC WITH (NOLOCK)
              ON (SKUxLOC.Storerkey = SKU.Storerkey)
             AND (SKUxLOC.SKU = SKU.SKU)
             AND (SKUxLOC.Loc = PICKDETAIL.Loc)
      INNER JOIN LOC WITH (NOLOCK)
                ON (PICKDETAIL.Loc = LOC.Loc)
    LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (PICKDETAIL.Storerkey = CLR.Storerkey AND CLR.Code = 'SORTBYLOGICALLOC' 
                                          AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_print_wave_pickslip_20' AND ISNULL(CLR.Short,'') <> 'N')
   LEFT OUTER JOIN Codelkup CLR1 (NOLOCK) ON (PICKDETAIL.Storerkey = CLR1.Storerkey AND CLR1.Code = 'LAYOUT01' 
                                          AND CLR1.Listname = 'REPORTCFG' AND CLR1.Long = 'r_dw_print_wave_pickslip_20' AND ISNULL(CLR1.Short,'') <> 'N')      
      WHERE  PICKHeader.PickHeaderKey = @c_PickHeaderKey 
        AND  PICKDETAIL.QTY > 0                                
      GROUP BY LoadPlanDetail.LoadKey,   
                  PICKHeader.PickHeaderKey,   
                  ISNULL(LoadPlan.Route,''),   
                  LoadPlan.AddDate,   
                  PICKDETAIL.Loc,   
                  PICKDETAIL.Sku,   
                  ISNULL(SKU.DESCR,''),   
                  PACK.CaseCnt,  
                  PACK.PackKey,
                  Pack.PackUOM3, 
                  ISNULL(LTRIM(RTRIM(SKU.PrePackIndicator)),''), 
                  SKU.PackQtyIndicator,
                  SKU.Size,
             --CASE WHEN LOC.LocationType <> 'PICK'             --CS02 START
             --        THEN 'BULK' 
             --     ELSE 'PICK'
             --      END,
               CASE WHEN LOC.LocationType='OTHER' THEN '0'
                            WHEN  LOC.LocationType='PICK' THEN '1'
                            WHEN LOC.LocationType='DYNPPICK' THEN '2'
              ELSE LOC.LocationType END ,                         --CS02 END
                 ISNULL(SKU.Busr6,''),
                 CASE WHEN ISNULL(CLR.CODE,'') <> '' THEN
                     LOC.LogicalLocation ELSE LOC.Loc END, 
             CASE WHEN CLR1.Code IS NOT NULL THEN '1' ELSE '0' END 
                 ,LOC.locationRoom           
               --,Loc.locationGroup
               --,LOC.PickZone
                 

   END -- @n_continue = 1 or @n_continue = 2

   --Reportcfg is OFF
   IF(ISNULL(@c_ShowTotal,'N') = 'N' OR ISNULL(@c_ShowTotal,'N') = '')
   BEGIN
      --SELECT * FROM #TEMPWAVCONSO20 ORDER BY pickslipno,loadkey,LOCATIONTYPE,locroom,Logicallocation,LOC,SKU
        SELECT 
              loadkey          
              ,pickslipno       
              ,route            
              ,adddate          
              ,loc              
              ,sku              
              ,QTY              
              ,sku_descr        
              ,casecnt          
              ,packkey          
              ,totalqtyordered  
              ,totalqtyalloc    
              ,uom3             
              ,prepackindicator 
              ,packqtyindicator 
              ,size             
              ,locationtype     
              ,busr6            
              ,Logicallocation  
              ,layout           
              ,showtotal        
            -- ,(Row_number() OVER (PARTITION BY pickslipno ORDER BY pickslipno,loadkey,LOCATIONTYPE,Logicallocation,LOC,SKU asc)-1)/@n_MaxLine+1 AS RECGROUP
             ,(Row_number() OVER (PARTITION BY loadkey,locRoom ORDER BY pickslipno,loadkey,LOCATIONTYPE,Logicallocation,LOC,SKU,size,casecnt asc)-1)/@n_MaxLine+1 AS RECGROUP
             ,locRoom
             ,locgrp
             ,LPickZone
         FROM #TEMPWAVCONSO20 
   END
   ELSE IF (ISNULL(@c_ShowTotal,'N') = 'Y') --Reportcfg is ON
   BEGIN
   INSERT INTO #TEMPWAVCONSO20_1
   SELECT 
     loadkey          
     ,pickslipno       
     ,route            
     ,adddate          
     ,loc              
     ,sku              
     ,QTY              
     ,sku_descr        
     ,casecnt          
     ,packkey          
     ,totalqtyordered  
     ,totalqtyalloc    
     ,uom3             
     ,prepackindicator 
     ,packqtyindicator 
     ,size             
     ,locationtype     
     ,busr6            
     ,Logicallocation  
     ,layout           
     ,showtotal        
    -- ,(Row_number() OVER (PARTITION BY pickslipno ORDER BY pickslipno,loadkey,LOCATIONTYPE,Logicallocation,LOC,SKU asc)-1)/@n_MaxLine+1 AS RECGROUP
     ,(Row_number() OVER (PARTITION BY loadkey,locRoom ORDER BY pickslipno,loadkey,LOCATIONTYPE,Logicallocation,LOC,SKU,size,casecnt asc)-1)/@n_MaxLine+1 AS RECGROUP
     ,locRoom
     ,locgrp
     ,LPickZone
     FROM #TEMPWAVCONSO20

     SELECT * FROM #TEMPWAVCONSO20_1 
     ORDER BY pickslipno,loadkey,LOCATIONTYPE,locroom,Logicallocation,LOC,SKU

     END


   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN

      execute nsp_logerror @n_err, @c_errmsg, 'isp_GetPickSlipWave20'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      --RAISERROR @n_err @c_errmsg
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
END /* main procedure */

GO