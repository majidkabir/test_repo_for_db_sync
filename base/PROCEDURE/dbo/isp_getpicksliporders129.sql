SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/***************************************************************************/      
/* Stored Proc : isp_GetPickSlipOrders129                                  */      
/* Creation Date: 25-MAY-2022                                              */      
/* Copyright: IDS                                                          */      
/* Written by:CHONGCS                                                      */      
/*                                                                         */      
/* Purpose: WMS-19707 SG - TRIPLE - Picking Slip Report [CR]               */      
/*                                                                         */      
/*                                                                         */      
/* Usage:                                                                  */      
/*                                                                         */      
/* Local Variables:                                                        */      
/*                                                                         */      
/* Called By: r_dw_print_pickorder129                                      */      
/*                                                                         */      
/* PVCS Version: 1.0                                                       */      
/*                                                                         */      
/* Version: 5.4                                                            */      
/*                                                                         */      
/* Data Modifications:                                                     */      
/*                                                                         */      
/* Updates:                                                                */      
/* Date        Author      Ver   Purposes                                  */   
/* 22-NOV-2022 CHONGCS     1.0   Devops Scripts Combine & WMS-21188 (CS01) */
/***************************************************************************/      
      
CREATE PROC [dbo].[isp_GetPickSlipOrders129] (@c_loadkey NVARCHAR(10) )      
AS      
BEGIN      
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
     
      
   DECLARE  @c_pickheaderkey        NVARCHAR(10),      
            @n_continue             INT,      
            @c_errmsg               NVARCHAR(255),      
            @b_success              INT,      
            @n_err                  INT,      
            @c_sku                  NVARCHAR(22),      
            @n_qty                  INT,      
            @c_loc                  NVARCHAR(10),      
            @n_cases                INT,      
            @n_perpallet            INT,      
            @c_storer               NVARCHAR(15),      
            @c_orderkey             NVARCHAR(10),      
            @c_ConsigneeKey         NVARCHAR(15),      
            @c_Company              NVARCHAR(100),      
            @c_Addr1                NVARCHAR(45),      
            @c_Addr2                NVARCHAR(45),      
            @c_Addr3                NVARCHAR(45),      
            @c_PostCode             NVARCHAR(15),      
            @c_Route                NVARCHAR(10),      
            @c_Route_Desc           NVARCHAR(60), -- RouteMaster.Desc      
            @c_TrfRoom              NVARCHAR(5),  -- LoadPlan.TrfRoom      
            @c_Notes1               NVARCHAR(200),      
            @c_Notes2               NVARCHAR(200),     
            @c_SkuDesc              NVARCHAR(60),      
            @n_CaseCnt              INT,      
            @n_PalletCnt            INT,      
            @c_ReceiptTm            NVARCHAR(20),      
            @c_PrintedFlag          NVARCHAR(1),      
            @c_UOM                  NVARCHAR(10),      
            @n_UOM3                 INT,      
            @c_Lot                  NVARCHAR(10),      
            @c_StorerKey            NVARCHAR(15),      
            @c_Zone                 NVARCHAR(1),      
            @n_PgGroup              INT,      
            @n_TotCases             INT,      
            @n_RowNo                INT,     
            @c_PrevSKU              NVARCHAR(20),      
            @n_SKUCount             INT,      
            @c_Carrierkey           NVARCHAR(60),      
            @c_VehicleNo            NVARCHAR(10),      
            @c_firstorderkey        NVARCHAR(10),      
            @c_superorderflag       NVARCHAR(1),      
            @c_firsttime            NVARCHAR(1),      
            @c_logicalloc           NVARCHAR(18),      
            @c_Lottable01           NVARCHAR(18),      
            @c_Lottable02           NVARCHAR(18),      
            @c_Lottable03           NVARCHAR(18),      
            @d_Lottable04           DATETIME,      
            @d_Lottable05           DATETIME,      
            @n_packpallet           INT,      
            @n_packcasecnt          INT,      
            @c_externorderkey       NVARCHAR(50),       
            @n_pickslips_required   INT,      
            @dt_deliverydate        DATETIME      
          , @n_TBLSkuPattern        INT               
          , @n_SortBySkuLoc         INT                
          , @c_PalletID        NVARCHAR(30)               
            
   DECLARE  @c_PrevOrderKey NVARCHAR(10),      
            @n_Pallets      INT,      
            @n_Cartons      INT,      
            @n_Eaches       INT,      
            @n_UOMQty       INT,      
            @c_Susr3        NVARCHAR(18),         
            @c_InvoiceNo    NVARCHAR(10),           
            @c_GetLoadkey   NVARCHAR(10),
            @c_getExtordkey NVARCHAR(50),      --CS01  S
            @c_getprevExtordkey NVARCHAR(50),  
            @c_getgpazone   NVARCHAR(10),
            @c_prevgpazone  NVARCHAR(10),
            @c_newcnt       NVARCHAR(1), 
            @n_rowcnt       INT  =1            --CS01 E
             
      
   DECLARE @n_starttcnt INT      
   SELECT  @n_starttcnt = @@TRANCOUNT      
   SET     @n_continue  = 1    
      
   WHILE @@TRANCOUNT > 0      
   BEGIN      
      COMMIT TRAN      
   END      
       
   --IF (@c_Status <> 'FIXTURES')    
   --BEGIN    
   --   GOTO QUIT_SP    
   --END    
    
   SET @n_pickslips_required = 0      
    
   SET @c_GetLoadkey = @c_loadkey    
    
   IF @n_continue = 1 OR @n_continue = 2    
   BEGIN    
      IF NOT EXISTS (SELECT 1 FROM Loadplan (NOLOCK) WHERE Loadkey = @c_GetLoadkey)    
      BEGIN    
         SELECT @c_loadkey = Loadkey    
         FROM ORDERS (NOLOCK)     
         WHERE Orderkey = @c_GetLoadkey    
      END    
   END    
    
   IF @n_continue = 1 OR @n_continue = 2    
   BEGIN    
      BEGIN TRAN      
    
           CREATE TABLE #TMP_PICK    
            (  PickSlipNo         NVARCHAR(10) NULL,  --    
               LoadKey            NVARCHAR(10),      
               OrderKey           NVARCHAR(10),      
               OHUDF09            NVARCHAR(10) NULL,  --    
               Qty                int,     
               PrintedFlag        NVARCHAR(1) NULL,        
               Storerkey          NVARCHAR(15) NULL,     
               CCountry           NVARCHAR(45) NULL,    
           --    Wavekey            NVARCHAR(10) NULL,    
               GPAZone            NVARCHAR(10) NULL,    
               PAZone             NVARCHAR(10) NULL,    
               PODArrive          DATETIME,   --8 dd/mm/yy    
               DELDate            DATETIME,   --mm/dd/yy    
               externorderkey     NVARCHAR(50) null,     
               CCompany           NVARCHAR(100) NULL,
               Extordkeyrowno     INT)         --CS01
                        
   END    
    
    
   IF @n_continue = 1 OR @n_continue = 2    
   BEGIN    
      -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 8 - By Order      
      IF EXISTS( SELECT 1 FROM PickHeader (NOLOCK)      
                 WHERE loadkey = @c_loadkey      
                 AND   Zone = '3' )      
      BEGIN      
         SELECT @c_firsttime = 'N'      
         SELECT @c_PrintedFlag = 'Y'      
      END      
      ELSE      
      BEGIN      
         SELECT @c_firsttime = 'Y'      
         SELECT @c_PrintedFlag = 'N'    
      END -- Record Not Exists      
   END    
       
   IF @n_continue = 1 OR @n_continue = 2    
   BEGIN               
      INSERT INTO #TMP_PICK    
      (    
          PickSlipNo,    
          LoadKey,    
          OrderKey,    
          OHUDF09,    
          Qty,    
          PrintedFlag,    
          Storerkey,    
          CCountry,    
         -- Wavekey,    
          GPAZone,    
          PAZone,    
          PODArrive,    
          DELDate,    
          externorderkey,    
          CCompany,Extordkeyrowno)            --CS01    
      SELECT (SELECT PICKHEADERKEY FROM PICKHEADER (NOLOCK)      
              WHERE ExternOrderKey = @c_LoadKey      
                AND OrderKey = PickDetail.OrderKey      
                AND Zone = '3'),      
            @c_LoadKey as LoadKey,      
            PickDetail.OrderKey,      
            ISNULL(ORDERS.userdefine09, '') AS OHUDF09,      
            SUM(PickDetail.qty) AS Qty,    
            ISNULL((SELECT DISTINCT 'Y' FROM PickHeader (NOLOCK) WHERE ExternOrderKey = @c_LoadKey      
                    AND Zone = '3'), 'N') AS PrintedFlag,    
            ORDERS.storerkey AS storerkey,     
            ISNULL(ORDERS.c_country, '') AS CCountry,      
            UPPER(SUBSTRING(loc.pickzone,1,2)) AS GPAZone,    
            loc.PickZone AS PAZone,    
            ORDERS.PODArrive ,      
            ORDERS.deliverydate ,    
            ORDERS.ExternOrderKey AS ExternOrderKey,        
            ISNULL(ORDERS.c_company, '') AS CCompany,1 --CS01
            --ROW_NUMBER() OVER(PARTITION BY ORDERS.ExternOrderKey
            --         ORDER BY PickDetail.OrderKey, ISNULL(ORDERS.userdefine09, ''),UPPER(SUBSTRING(loc.pickzone,1,2)),ORDERS.ExternOrderKey,loc.PickZone) AS Extordkeyrowno   --CS01                                                                             --CS01
      FROM LOADPLANDETAIL (NOLOCK)      
      JOIN ORDERS (NOLOCK) ON (ORDERS.Orderkey = LoadPlanDetail.Orderkey)      
      JOIN ORDERDETAIL (NOLOCK) ON (ORDERDETAIL.Orderkey = ORDERS.Orderkey)      
      JOIN Storer (NOLOCK) ON (ORDERS.StorerKey = Storer.StorerKey)      
      LEFT OUTER JOIN RouteMaster ON (RouteMaster.Route = ORDERS.Route)      
      JOIN PickDetail (NOLOCK) ON (PickDetail.OrderKey = ORDERDETAIL.Orderkey and PickDetail.OrderLineNumber = ORDERDETAIL.OrderLineNumber )       
      JOIN Sku (NOLOCK)  ON (Sku.StorerKey = PickDetail.StorerKey AND Sku.Sku = PickDetail.Sku)      
      JOIN LOC (NOLOCK) ON (PICKDETAIL.LOC = LOC.LOC)           
      WHERE PickDetail.Status >= '0'      
       AND LoadPlanDetail.LoadKey = @c_LoadKey      
      GROUP BY PickDetail.OrderKey,      
            ISNULL(ORDERS.userdefine09, '') ,      
            ORDERS.storerkey,     
            ISNULL(ORDERS.c_country, ''),      
            UPPER(SUBSTRING(loc.pickzone,1,2)),    
            loc.PickZone,    
            ORDERS.PODArrive ,      
            ORDERS.deliverydate ,    
            ORDERS.ExternOrderKey,        
            ISNULL(ORDERS.c_company, '')    
   END    
    --CS01 S
  SET @c_prevgpazone = ''
  SET @n_rowcnt = 1
  SET @c_getprevExtordkey = ''
  SET @c_newcnt = 'N'

   DECLARE C_CURSOR_Extordkey CURSOR FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT externorderkey,GPAZone  
     FROM #TMP_PICK  
    ORDER BY externorderkey,GPAZone  
  
   OPEN C_CURSOR_Extordkey  
   FETCH NEXT FROM C_CURSOR_Extordkey INTO @c_getExtordkey,@c_getgpazone  
  
    WHILE @@FETCH_STATUS <> -1  
    BEGIN  

  -- SELECT @c_getExtordkey '@c_getExtordkey', @c_getgpazone '@c_getgpazone', @n_rowcnt '@n_rowcnt'

   IF @n_rowcnt = 1
   BEGIN
           UPDATE #TMP_PICK
           SET Extordkeyrowno = @n_rowcnt
           WHERE externorderkey = @c_getExtordkey AND GPAZone=@c_getgpazone   
           SET @c_newcnt = 'N'
   END
   ELSE
   BEGIN

       IF @c_getprevExtordkey = @c_getExtordkey
       BEGIN
              IF @c_prevgpazone<>@c_getgpazone
              BEGIN
                    UPDATE #TMP_PICK
                    SET Extordkeyrowno = @n_rowcnt
                    WHERE externorderkey = @c_getExtordkey AND GPAZone=@c_getgpazone  
              END 
              ELSE
              BEGIN
                    UPDATE #TMP_PICK
                    SET Extordkeyrowno = Extordkeyrowno
                    WHERE externorderkey = @c_getExtordkey AND GPAZone=@c_getgpazone 
                    SET @c_newcnt = 'Y'
              END
       END
       ELSE
       BEGIN
              SET @n_rowcnt = 1
               UPDATE #TMP_PICK
               SET Extordkeyrowno = @n_rowcnt
               WHERE externorderkey = @c_getExtordkey AND GPAZone=@c_getgpazone  

       END
   END

    SET @c_getprevExtordkey = @c_getExtordkey
    SET @c_prevgpazone = @c_getgpazone
   -- SET @n_rowcnt = @n_rowcnt + 1
    
    IF @c_newcnt ='Y'
    BEGIN
      SET @n_rowcnt = 1
    END
    ELSE
    BEGIN
       SET @n_rowcnt = @n_rowcnt + 1
    END

      FETCH NEXT FROM C_CURSOR_Extordkey INTO @c_getExtordkey,@c_getgpazone  

      END         
      CLOSE C_CURSOR_Extordkey
      DEALLOCATE C_CURSOR_Extordkey
    --CS01 E
    
   IF @n_continue = 1 OR @n_continue = 2    
   BEGIN    
      BEGIN TRAN      
      -- Uses PickType as a Printed Flag         
      UPDATE PickHeader      
         SET PickType = '1',      
             TrafficCop = NULL      
      WHERE loadkey = @c_loadkey      
      AND Zone = '3'    
      AND PickType = '0'      
      
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
            -- SELECT @c_PrintedFlag = "Y"      
         END      
         ELSE      
         BEGIN      
            SELECT @n_continue = 3      
            ROLLBACK TRAN      
         END      
      END      
      
      WHILE @@TRANCOUNT > 0      
      BEGIN      
         COMMIT TRAN      
      END      
      
      SELECT @n_pickslips_required = COUNT(DISTINCT OrderKey)      
      FROM #TMP_PICK      
      WHERE ISNULL(RTRIM(PickSlipNo),'') = ''     
      
      IF @@ERROR <> 0      
      BEGIN      
         GOTO FAILURE      
      END      
      ELSE IF @n_pickslips_required > 0      
      BEGIN      
         BEGIN TRAN      
         EXECUTE nspg_GetKey 'PICKSLIP', 9, @c_pickheaderkey OUTPUT, @b_success OUTPUT, @n_err  OUTPUT, @c_errmsg OUTPUT, 0, @n_pickslips_required      
         COMMIT TRAN      
      
         BEGIN TRAN      
         INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, PickType, Zone, TrafficCop,LoadKey)      
         SELECT 'P' + RIGHT ( REPLICATE ('0', 9) +      
                      dbo.fnc_LTrim( dbo.fnc_RTrim(      
                      STR(      
                           CAST(@c_pickheaderkey AS INT) + ( SELECT COUNT(DISTINCT orderkey)      
                                                             FROM #TMP_PICK as Rank      
                                                             WHERE Rank.OrderKey < #TMP_PICK.OrderKey      
           AND ISNULL(RTRIM(Rank.PickSlipNo),'') = '' )     
                          ) -- str      
                         )) -- dbo.fnc_RTrim      
                      , 9)      
                , OrderKey, LoadKey, '0', '3', '' ,LoadKey     
         FROM #TMP_PICK WHERE ISNULL(RTRIM(PickSlipNo),'') = ''     
         GROUP By LoadKey, OrderKey      
      
         UPDATE #TMP_PICK      
         SET PickSlipNo = PICKHEADER.PickHeaderKey      
         FROM PICKHEADER (NOLOCK)      
         WHERE PICKHEADER.loadkey = #TMP_PICK.LoadKey      
           AND PICKHEADER.OrderKey = #TMP_PICK.OrderKey      
           AND PICKHEADER.Zone = '3'      
           AND ISNULL(RTRIM(#TMP_PICK.PickSlipNo),'') = ''     
      
         UPDATE PICKDETAIL      
         SET PickSlipNo = #TMP_PICK.PickSlipNo,      
             TrafficCop = NULL      
         FROM #TMP_PICK      
         WHERE #TMP_PICK.OrderKey = PICKDETAIL.OrderKey      
           AND ISNULL(RTRIM(PICKDETAIL.PickSlipNo),'') = ''     
      
         WHILE @@TRANCOUNT > 0      
         BEGIN      
            COMMIT TRAN      
         END      
      END      
        GOTO SUCCESS      
   END    
    
   IF @n_continue = 1 OR @n_continue = 2    
   BEGIN    
   FAILURE:      
      DELETE FROM #TMP_PICK      
   SUCCESS:      
      SELECT       
          PickSlipNo,    
          LoadKey,    
          Qty,    
          Storerkey,    
          OrderKey,    
          OHUDF09,    
          #TMP_PICK.GPAZone,    
          #TMP_PICK.PAZone,    
         CCountry,    
         -- Wavekey,      
          CONVERT(NVARCHAR(8),PODArrive,103) as PODArrive,    
          CONVERT(NVARCHAR(8),DELDate,103) AS DELDate,    
          externorderkey,    
          CCompany,    
          PrintedFlag,CAST(#TMP_PICK.Extordkeyrowno AS NVARCHAR(5)),CAST(TP2.TTLextordpage AS NVARCHAR(5))           
      FROM #TMP_PICK   
      CROSS APPLY( SELECT externorderkey AS Extordkey,MAX(TP2.Extordkeyrowno) AS TTLextordpage FROM #TMP_PICK TP2  WITH (NOLOCK) 
                   WHERE TP2.PickSlipNo=#TMP_PICK.PickSlipNo AND TP2.loadkey=#TMP_PICK.loadkey AND TP2.OrderKey=#TMP_PICK.orderkey AND TP2.storerkey = #TMP_PICK.Storerkey
                   GROUP BY externorderkey) AS TP2   
      ORDER BY  PickSlipNo, OHUDF09,loadkey    
            ,  Orderkey      
            ,  #TMP_PICK.GPAZone,#TMP_PICK.PAZone     
     
      DROP Table #TMP_PICK      
   END    
    
QUIT_SP:    
   IF @n_Continue=3  -- Error Occured - Process And Return      
   BEGIN      
      SET @b_Success = 0      
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt      
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
      
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_GetPickSlipOrders129'      
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012      
   END      
   ELSE      
   BEGIN      
      SET @b_Success = 1      
      WHILE @@TRANCOUNT > @n_StartTCnt      
      BEGIN      
         COMMIT TRAN      
      END      
   END     
      
   WHILE @@TRANCOUNT < @n_starttcnt      
   BEGIN      
      BEGIN TRAN      
   END      
END      


GO