SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/    
/* Stored Procedure: isp_GetPickSlipOrders125                            */    
/* Creation Date: 14-Oct-2021                                            */    
/* Copyright: LFL                                                        */    
/* Written by: WLChooi                                                   */    
/*                                                                       */    
/* Purpose: WMS-18143 - LM Pickslip                                      */    
/*                                                                       */    
/* Called By: r_dw_print_pickorder125                                    */    
/*                                                                       */    
/* GitLab Version: 1.0                                                   */    
/*                                                                       */    
/* Version: 5.4                                                          */    
/*                                                                       */    
/* Data Modifications:                                                   */    
/*                                                                       */    
/* Updates:                                                              */    
/* Date         Author   Ver  Purposes                                   */  
/* 14-Oct-2021  WLChooi  1.0  DevOps Combine Script                      */
/* 16-Dec-2021  Mingle   1.1  Add new mappings(ML01)                     */
/* 16-DEC-2021  Mingle   1.1  DevOps Combine Script                      */
/*************************************************************************/  
CREATE PROC [dbo].[isp_GetPickSlipOrders125] (@c_loadkey NVARCHAR(10))     
AS    
BEGIN  
   SET NOCOUNT ON     
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    
     
   DECLARE @c_pickheaderkey NVARCHAR(10),  
           @n_continue INT,  
           @c_errmsg NVARCHAR(255),  
           @b_success INT,  
           @n_err INT,  
           @c_sku NVARCHAR(20),  
           @n_qty INT,  
           @c_loc NVARCHAR(10),  
           @n_cases INT,  
           @n_perpallet INT,  
           @c_storer NVARCHAR(15),  
           @c_orderkey NVARCHAR(10),  
           @c_ConsigneeKey NVARCHAR(15),  
           @c_Company NVARCHAR(45),  
           @c_Addr1 NVARCHAR(45),  
           @c_Addr2 NVARCHAR(45),  
           @c_Addr3 NVARCHAR(45),  
           @c_PostCode NVARCHAR(15),  
           @c_Route NVARCHAR(10),  
           @c_Route_Desc NVARCHAR(60),  
           @c_TrfRoom NVARCHAR(5),  
           @c_Notes1 NVARCHAR(60),  
           @c_Notes2 NVARCHAR(60),  
           @c_SkuDesc NVARCHAR(60),  
           @n_CaseCnt INT,  
           @n_PalletCnt INT,  
           @c_ReceiptTm NVARCHAR(20),  
           @c_PrintedFlag NVARCHAR(1),  
           @c_UOM NVARCHAR(10),  
           @n_UOM3 INT,  
           @c_StorerKey NVARCHAR(15),  
           @c_Zone NVARCHAR(1),  
           @n_PgGroup INT,  
           @n_TotCases INT,  
           @n_RowNo INT,  
           @c_PrevSKU NVARCHAR(20),  
           @n_SKUCount INT,  
           @c_Carrierkey NVARCHAR(60),  
           @c_VehicleNo NVARCHAR(10),  
           @c_firstorderkey NVARCHAR(10),  
           @c_superorderflag NVARCHAR(1),  
           @c_firsttime NVARCHAR(1),  
           @c_logicalloc NVARCHAR(18),  
           @c_Lottable01 NVARCHAR(18),  
           @d_Lottable04 DATETIME,  
           @n_packpallet INT,  
           @n_packcasecnt INT,  
           @c_externorderkey NVARCHAR(30),  
           @n_pickslips_required INT,  
           @c_skugroup NVARCHAR(10),
           @c_skunotes1 NVARCHAR(200), --ML01
           @c_extfield01 NVARCHAR(30) --ML01    
     
   DECLARE @c_PrevOrderKey     NVARCHAR(10),  
           @n_Pallets          INT,  
           @n_Cartons          INT,  
           @n_Eaches           INT,  
           @n_UOMQty           INT    
           
   DECLARE @c_getPickslipno NVARCHAR(10)
          ,@c_getloadkey NVARCHAR(20)
          ,@c_getorderkey NVARCHAR(50)
          ,@c_Rptdescr NVARCHAR(150)

   DECLARE @n_starttcnt INT  
   SELECT  @n_starttcnt = @@TRANCOUNT  
  
   WHILE @@TRANCOUNT > 0  
   BEGIN  
      COMMIT TRAN  
   END  
  
   SET @n_pickslips_required = 0
   
   BEGIN TRAN    
   CREATE TABLE #TEMP_PICK  
   (  
      PickSlipNo         NVARCHAR(10) NULL,  
      LoadKey            NVARCHAR(10),  
      OrderKey           NVARCHAR(10),  
      Company            NVARCHAR(100),  
      Addr1              NVARCHAR(100) NULL,  
      Addr2              NVARCHAR(100) NULL,  
      Addr3              NVARCHAR(100) NULL,  
      Addr4              NVARCHAR(100) NULL,  
      C_Country          NVARCHAR(100) NULL,  
      PostCode           NVARCHAR(15) NULL,  
      [ROUTE]            NVARCHAR(10) NULL,  
      Route_Desc         NVARCHAR(60) NULL,  
      TrfRoom            NVARCHAR(5) NULL,  
      Notes1             NVARCHAR(60) NULL,  
      LOC                NVARCHAR(10) NULL,  
      SKU                NVARCHAR(20),  
      SkuDesc            NVARCHAR(60),  
      Qty                INT,  
      TempQty1           INT,  
      TempQty2           INT,  
      PrintedFlag        NVARCHAR(1) NULL,  
      [Zone]             NVARCHAR(1),  
      PgGroup            INT,  
      RowNum             INT,  
      Carrierkey         NVARCHAR(60) NULL,  
      VehicleNo          NVARCHAR(10) NULL,  
      Lottable01         NVARCHAR(18) NULL,  
      Lottable04         DATETIME NULL,  
      packpallet         INT,  
      packcasecnt        INT,  
      packinner          INT,  
      packeaches         INT,  
      externorderkey     NVARCHAR(30) NULL,  
      LogicalLoc         NVARCHAR(18) NULL,  
      UOM                NVARCHAR(10),  
      Pallet_cal         INT,  
      Cartons_cal        INT,  
      inner_cal          INT,  
      Each_cal           INT,  
      Total_cal          INT,  
      DeliveryDate       DATETIME NULL,  
      RetailSku          NVARCHAR(20) NULL,  
      BuyerPO            NVARCHAR(20) NULL,  
      InvoiceNo          NVARCHAR(20) NULL,  
      OrderDate          DATETIME NULL,   
      OVAS               NVARCHAR(30) NULL,  
      SKUGROUP           NVARCHAR(10) NULL,  
      Storerkey          NVARCHAR(15) NULL,  
      stdcube            DECIMAL(30,5),              
      GrossWgt           DECIMAL(30,5),
      OrderType          NVARCHAR(250),
      QtyPerCtn          NVARCHAR(100),
      SKUNOTES1          NVARCHAR(200) NULL,  --ML01
      extfield01         NVARCHAR(30) NULL   --ML01   
   )  
     
   SELECT TOP 1 @c_storerkey = Storerkey  
   FROM ORDERS (NOLOCK)  
   WHERE Loadkey = @c_Loadkey  

   SELECT Storerkey,
          ShowSkufield   =  ISNULL(MAX(CASE WHEN Code = 'SHOWSKUFIELD'  THEN 1 ELSE 0 END),0) 
         ,ShowPriceTag   =  ISNULL(MAX(CASE WHEN Code = 'SHOWPRICETAG'  THEN 1 ELSE 0 END),0)  
         ,ShowItemClass  =  ISNULL(MAX(CASE WHEN Code = 'ShowItemClass'  THEN 1 ELSE 0 END),0) 
         ,ShowExtraField =  ISNULL(MAX(CASE WHEN Code = 'ShowExtraField'  THEN 1 ELSE 0 END),0)
   INTO #TMP_RPTCFG
   FROM CODELKUP WITH (NOLOCK)
   WHERE ListName = 'REPORTCFG'
   AND Long      = 'r_dw_print_pickorder125'
   AND (Short IS NULL OR Short <> 'N')
   GROUP BY Storerkey
      
   INSERT INTO #TEMP_PICK  
   (  
       PickSlipNo,  
       LoadKey,  
       OrderKey,  
       Company,  
       Addr1,  
       Addr2,  
       PgGroup,  
       Addr3,  
       Addr4,
       C_Country,
       PostCode,  
       ROUTE,  
       Route_Desc,  
       TrfRoom,  
       Notes1,  
       RowNum,    
       LOC,
       SKU,  
       SkuDesc,  
       Qty,  
       TempQty1,  
       TempQty2,  
       PrintedFlag,  
       Zone, 
       CarrierKey,  
       VehicleNo,   
       Lottable01,  
       Lottable04,  
       packpallet,  
       packcasecnt,  
       packinner,  
       packeaches,  
       externorderkey,  
       LogicalLoc,  
       UOM,  
       Pallet_cal,  
       Cartons_cal,  
       inner_cal,  
       Each_cal,  
       Total_cal,  
       DeliveryDate,  
       RetailSku,  
       BuyerPO,  
       InvoiceNo,  
       OrderDate,      
       OVAS,  
       SKUGROUP,  
       Storerkey,
       stdcube,
       GrossWgt,
       OrderType,
       QtyPerCtn,
       SKUNOTES1, --ML01
       extfield01 --ML01
   )
   SELECT (  
              SELECT PICKHEADERKEY  
              FROM   PICKHEADER WITH (NOLOCK)  
              WHERE  ExternOrderKey     = @c_LoadKey  
                     AND Orderkey       = Pickdetail.Orderkey  
                     AND ZONE           = '3'  
          ),  
          @c_LoadKey                     AS LoadKey,  
          Pickdetail.Orderkey,  
          ISNULL(ORDERS.c_Company, '')   AS Company,  
          ISNULL(ORDERS.C_Address1, '')  AS Addr1,  
          ISNULL(ORDERS.C_Address2, '')  AS Addr2,  
          0                              AS PgGroup,  
          ISNULL(ORDERS.C_Address3, '')  AS Addr3, 
          ISNULL(ORDERS.C_Address4, '')  AS Addr4,  
          ISNULL(ORDERS.C_Country, '')   AS C_Country,
          ISNULL(ORDERS.C_Zip, '')       AS PostCode,  
          ISNULL(ORDERS.Route, '')       AS Route,  
          ISNULL(Routemaster.Descr, '')     Route_Desc,  
          CONVERT(NVARCHAR(5), ORDERS.Door)  AS TrfRoom,  
          CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes, '')) Notes1,  
          0                              AS RowNo,  
          Pickdetail.LOC,   
          Pickdetail.SKU,  
          ISNULL(SKU.Descr, '')             SkuDescr,  
          SUM(Pickdetail.qty)            AS Qty,  
          1                              AS UOMQTY,  
          0                              AS TempQty2,  
          ISNULL(  
              (  
                  SELECT DISTINCT 'Y'  
                  FROM   PickHeader(NOLOCK)  
                  WHERE  ExternOrderKey     = @c_Loadkey  
                         AND Zone           = '3'  
              ),  
              'N'  
          )                              AS PrintedFlag,  
          '3' Zone,   
          '' CarrierKey,  
          '' AS VehicleNo,  
          Lotattribute.Lottable01,
          ISNULL(Lotattribute.Lottable04, '19000101') Lottable04,  
          Pack.Pallet,  
          Pack.CaseCnt,  
          Pack.innerpack,  
          Pack.Qty,  
          ORDERS.ExternOrderKey           AS ExternOrderKey,  
          ISNULL(LOC.LogicalLocation, '') AS LogicalLocation,  
          ISNULL(Orderdetail.UOM, '')     AS UOM,  
          Pallet_cal = CASE Pack.Pallet  
                            WHEN 0 THEN 0  
                            ELSE FLOOR(SUM(Pickdetail.qty) / Pack.Pallet)  
                       END,  
          Cartons_cal = 0,  
          inner_cal   = 0,  
          Each_cal    = 0,  
          Total_cal   = SUM(Pickdetail.qty),  
          ISNULL(ORDERS.DeliveryDate, '19000101') DeliveryDate,  
          ISNULL(SKU.RetailSku, '')         RetailSku,  
          ISNULL(ORDERS.BuyerPO, '')        BuyerPO,  
          ISNULL(ORDERS.InvoiceNo, '')      InvoiceNo,  
          ISNULL(ORDERS.OrderDate, '19000101') OrderDate,    
          SKU.OVAS,  
          SKU.SKUGROUP,  
          ORDERS.Storerkey,
          CASE WHEN ISNULL(SKU.STDCUBE,0) = 0 THEN (ISNULL(SKU.[Length],0) * ISNULL(SKU.[Width],0) * ISNULL(SKU.[Height],0)) * 0.000001 ELSE SKU.STDCUBE END,
          CASE WHEN ISNULL(SKU.STDGROSSWGT,0) = 0 THEN SKU.GrossWgt ELSE SKU.STDGROSSWGT END,
          ISNULL(CL.[Description],''),
          --TRIM(ISNULL(PACK.PackKey,'')) + ' = ' + CAST(ISNULL(PACK.CaseCnt,0) AS NVARCHAR(20)) AS QtyPerCtn
          --PACK.PackUOM3 AS QtyPerCtn
          PACK.PackKey, --ML01
          SKU.NOTES1, --ML01
          SKUINFO.ExtendedField01 --ML01
   FROM Pickdetail (NOLOCK)  
   JOIN ORDERS (NOLOCK) ON Pickdetail.Orderkey = ORDERS.Orderkey  
   JOIN Lotattribute (NOLOCK) ON Pickdetail.Lot = Lotattribute.Lot  
   JOIN Loadplandetail (NOLOCK) ON Pickdetail.Orderkey = Loadplandetail.Orderkey  
   JOIN Orderdetail (NOLOCK) ON Pickdetail.Orderkey = Orderdetail.Orderkey  
                            AND Pickdetail.orderlinenumber = Orderdetail.orderlinenumber  
   JOIN Storer (NOLOCK) ON Pickdetail.Storerkey = Storer.Storerkey  
   JOIN SKU (NOLOCK) ON Pickdetail.SKU = SKU.SKU AND Pickdetail.Storerkey = SKU.Storerkey  
   JOIN Pack (NOLOCK) ON Pickdetail.Packkey = Pack.Packkey  
   JOIN LOC (NOLOCK) ON Pickdetail.LOC = LOC.LOC 
   LEFT JOIN SKUINFO (NOLOCK) ON SkuInfo.Sku = SKU.Sku AND SkuInfo.Storerkey = PICKDETAIL.Storerkey --ML01
   LEFT JOIN Routemaster (NOLOCK) ON ORDERS.[Route] = Routemaster.[Route]  
   LEFT JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'ORDERTYPE' AND ORDERS.[Type] = CL.Code
   WHERE Loadplandetail.LoadKey = @c_LoadKey  
   GROUP BY Pickdetail.Orderkey,
            ISNULL(ORDERS.c_Company, ''),  
            ISNULL(ORDERS.C_Address1, ''),  
            ISNULL(ORDERS.C_Address2, ''),  
            ISNULL(ORDERS.C_Address3, ''), 
            ISNULL(ORDERS.C_Address4, ''),
            ISNULL(ORDERS.C_Country, ''), 
            ISNULL(ORDERS.C_Zip, ''),  
            ISNULL(ORDERS.Route, ''),  
            ISNULL(Routemaster.Descr, ''),  
            CONVERT(NVARCHAR(5), ORDERS.Door),  
            CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes, '')),   
            Pickdetail.LOC,  
            Pickdetail.SKU,  
            ISNULL(SKU.Descr, ''),  
            Lotattribute.Lottable01,
            ISNULL(Lotattribute.Lottable04, '19000101'),  
            Pack.Pallet,  
            Pack.CaseCnt,  
            Pack.innerpack,  
            Pack.Qty,  
            ORDERS.ExternOrderKey,  
            ISNULL(LOC.LogicalLocation, ''),  
            ISNULL(Orderdetail.UOM, ''),  
            ISNULL(ORDERS.DeliveryDate, '19000101'),  
            ISNULL(SKU.RetailSku, ''),  
            ISNULL(ORDERS.BuyerPO, ''),  
            ISNULL(ORDERS.InvoiceNo, ''),  
            ISNULL(ORDERS.OrderDate, '19000101'),  
            SKU.OVAS,  
            SKU.SKUGROUP,  
            ORDERS.Storerkey,
            CASE WHEN ISNULL(SKU.STDCUBE,0) = 0 THEN (ISNULL(SKU.[Length],0) * ISNULL(SKU.[Width],0) * ISNULL(SKU.[Height],0)) * 0.000001 ELSE SKU.STDCUBE END,
            CASE WHEN ISNULL(SKU.STDGROSSWGT,0) = 0 THEN SKU.GrossWgt ELSE SKU.STDGROSSWGT END,
            ISNULL(CL.[Description],''),
            --TRIM(ISNULL(PACK.PackKey,'')) + ' = ' + CAST(ISNULL(PACK.CaseCnt,0) AS NVARCHAR(20))
            --PACK.PackUOM3
            PACK.PackKey, --ML01
            SKU.NOTES1, --ML01
            SKUINFO.ExtendedField01 --ML01
         
   UPDATE #temp_pick  
   SET    cartons_cal = CASE packcasecnt  
                             WHEN 0 THEN 0  
                        ELSE FLOOR(total_cal / packcasecnt)  
                        END    
     
   UPDATE #temp_pick  
   SET    inner_cal = CASE packinner  
                           WHEN 0 THEN 0  
                           ELSE FLOOR(total_cal / packinner) -((packcasecnt * cartons_cal) / packinner)  
                      END    
     
   UPDATE #temp_pick  
   SET    each_cal = total_cal -(packcasecnt * cartons_cal) -(packinner * inner_cal)   
  
   BEGIN TRAN      
     
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
  
   WHILE @@TRANCOUNT > 0  
   BEGIN  
      COMMIT TRAN  
   END  
  
   SELECT @n_pickslips_required = COUNT(DISTINCT OrderKey)  
   FROM   #TEMP_PICK  
   WHERE ISNULL(RTRIM(PickSlipNo),'') = ''
     
   IF @@ERROR <> 0  
   BEGIN  
       GOTO FAILURE  
   END  
   ELSE   
   IF @n_pickslips_required > 0  
   BEGIN  
      BEGIN TRAN  
      EXECUTE nspg_GetKey 'PICKSLIP', 9, @c_pickheaderkey OUTPUT, @b_success OUTPUT, @n_err  OUTPUT, @c_errmsg OUTPUT, 0, @n_pickslips_required    
      COMMIT TRAN  
  
      BEGIN TRAN  
  
       INSERT INTO PICKHEADER  
         (  
           PickHeaderKey,  
           OrderKey,  
           ExternOrderKey,  
           PickType,  
           Zone,  
           TrafficCop  
         )  
       SELECT 'P' + RIGHT (  
                  REPLICATE('0', 9) +  
                  dbo.fnc_LTrim(  
                      dbo.fnc_RTrim(  
                          STR(  
                              CAST(@c_pickheaderkey AS INT) + (  
                                  SELECT COUNT(DISTINCT orderkey)  
                                  FROM   #TEMP_PICK AS RANK  
                                  WHERE  RANK.OrderKey < #TEMP_PICK.OrderKey  
                                  AND ISNULL(RTRIM(Rank.PickSlipNo),'') = ''
                              )  
                          ) -- str  
                      )  
                  ) -- dbo.fnc_RTrim    
                  ,  
                  9  
              ),  
              OrderKey,  
              LoadKey,  
              '0',  
              '3',  
              ''  
       FROM   #TEMP_PICK  
       WHERE ISNULL(RTRIM(PickSlipNo),'') = ''
       GROUP BY  
              LoadKey,  
              OrderKey  
         
       UPDATE #TEMP_PICK  
       SET    PickSlipNo = PICKHEADER.PickHeaderKey  
       FROM   PICKHEADER(NOLOCK)  
       WHERE  PICKHEADER.ExternOrderKey = #TEMP_PICK.LoadKey  
              AND PICKHEADER.OrderKey = #TEMP_PICK.OrderKey  
              AND PICKHEADER.Zone = '3'  
              AND   ISNULL(RTRIM(#TEMP_PICK.PickSlipNo),'') = ''
  
      WHILE @@TRANCOUNT > 0  
      BEGIN  
         COMMIT TRAN  
      END                
   END  
     
   GOTO SUCCESS   
     
   FAILURE:    
   DELETE   
   FROM   #TEMP_PICK   
     
   SUCCESS:  
     
   SELECT            
         #TEMP_PICK.PickSlipNo     
      ,  #TEMP_PICK.LoadKey            
      ,  #TEMP_PICK.OrderKey                
      ,  #TEMP_PICK.Company            
      ,  #TEMP_PICK.Addr1              
      ,  #TEMP_PICK.Addr2              
      ,  #TEMP_PICK.Addr3  
      ,  #TEMP_PICK.Addr4 
      ,  #TEMP_PICK.C_Country             
      ,  #TEMP_PICK.PostCode           
      ,  #TEMP_PICK.[ROUTE]              
      ,  ''   --#TEMP_PICK.Route_Desc         
      ,  #TEMP_PICK.TrfRoom            
      ,  #TEMP_PICK.Notes1              
      ,  UPPER(#TEMP_PICK.LOC) AS LOC                  
      ,  #TEMP_PICK.SKU                
      ,  #TEMP_PICK.SkuDesc            
      ,  #TEMP_PICK.Qty                
      ,  #TEMP_PICK.TempQty1           
      ,  #TEMP_PICK.TempQty2           
      ,  #TEMP_PICK.PrintedFlag        
      ,  #TEMP_PICK.Zone               
      ,  #TEMP_PICK.PgGroup            
      ,  #TEMP_PICK.RowNum                           
      ,  #TEMP_PICK.Carrierkey         
      ,  #TEMP_PICK.VehicleNo          
      ,  #TEMP_PICK.Lottable01         
      ,  #TEMP_PICK.Lottable04         
      ,  #TEMP_PICK.packpallet         
      ,  #TEMP_PICK.packcasecnt        
      ,  #TEMP_PICK.packinner          
      ,  #TEMP_PICK.packeaches         
      ,  #TEMP_PICK.externorderkey     
      ,  #TEMP_PICK.LogicalLoc     
      ,  #TEMP_PICK.UOM                
      ,  #TEMP_PICK.Pallet_cal         
      ,  #TEMP_PICK.Cartons_cal        
      ,  #TEMP_PICK.inner_cal          
      ,  #TEMP_PICK.Each_cal           
      ,  #TEMP_PICK.Total_cal          
      ,  #TEMP_PICK.DeliveryDate       
      ,  #TEMP_PICK.RetailSku          
      ,  ''   --#TEMP_PICK.BuyerPO            
      ,  #TEMP_PICK.InvoiceNo          
      ,  #TEMP_PICK.OrderDate                            
      ,  #TEMP_PICK.OVAS               
      ,  #TEMP_PICK.SKUGROUP           
      ,  #TEMP_PICK.Storerkey   
      ,  #TEMP_PICK.stdcube
      ,  #TEMP_PICK.GrossWgt    
      ,  #TEMP_PICK.OrderType        
      ,  #TEMP_PICK.QtyPerCtn   
      ,  #TEMP_PICK.SKUNOTES1  --ML01
      ,  #TEMP_PICK.extfield01 --ML01                                                                   
   FROM  #TEMP_PICK  
     
   IF OBJECT_ID('tempdb..#TEMP_PICK') IS NOT NULL
      DROP TABLE #TEMP_PICK 
     
   WHILE @@TRANCOUNT < @n_starttcnt  
   BEGIN  
      BEGIN TRAN  
   END          
END

GO