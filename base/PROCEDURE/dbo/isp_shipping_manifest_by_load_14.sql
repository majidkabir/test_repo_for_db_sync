SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: isp_shipping_manifest_by_load_14                    */  
/* Creation Date: 2019-Nov-29                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose:WMS-11271 CR1054-print DN report  CR                          */  
/*                                                                       */  
/* Called By: r_shipping_manifest_by_load_14                             */  
/*                                                                       */  
/* PVCS Version: 1.1                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author  Ver   Purposes                                   */  
/*************************************************************************/  
CREATE PROC [dbo].[isp_shipping_manifest_by_load_14]  
(    
 @c_loadkey    NVARCHAR(10)  
)  
           
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_DEFAULTS OFF    
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @c_storerkey      NVARCHAR(10)  
          ,@n_NoOfLine       INT  
          ,@c_getstorerkey   NVARCHAR(10)  
          ,@c_getLoadkey     NVARCHAR(20)  
          ,@c_getOrderkey    NVARCHAR(20)  
          ,@c_getExtOrderkey NVARCHAR(20)  
            
  CREATE TABLE #TMP_LoadOH11(  
           rowid           int identity(1,1),  
           storerkey       NVARCHAR(20) NULL,  
           loadkey         NVARCHAR(50) NULL,  
           Orderkey        NVARCHAR(10) NULL,  
           ExtOrdKey       NVARCHAR(60) NULL)             
      
   CREATE TABLE #TMP_SMBLOAD11 (  
          rowid           int identity(1,1),  
          Orderkey        NVARCHAR(20)  NULL,  
          loadkey         NVARCHAR(50)  NULL,  
          C_Company       NVARCHAR(45)  NULL,  
          SKU             NVARCHAR(20)  NULL,  
          SDESCR          NVARCHAR(150) NULL,  
          Lottable04      NVARCHAR(10)  NULL,  
          PQty            INT,  
          CaseCnt         FLOAT,  
          ExtOrdKey       NVARCHAR(60) NULL,    
          consigneekey    NVARCHAR(45) NULL,  
          C_Contact1      NVARCHAR(45) NULL,  
          C_Phone1        NVARCHAR(45) NULL,  
          CaseCnt2        INT,  
          PCS             INT,  
          STDNETWGT       FLOAT NULL,  
          StdCube         FLOAT NULL,  
          ST_Company      NVARCHAR(45) NULL,  
          C_Address1      NVARCHAR(45) NULL,  
          F_Address1      NVARCHAR(45) NULL  
          )         

   IF EXISTS (SELECT 1 FROM Orders WITH (NOLOCK) WHERE Loadkey = @c_loadkey)  
   BEGIN  
      INSERT INTO #TMP_LoadOH11 (storerkey, loadkey, Orderkey,ExtOrdKey)  
      SELECT OH.Storerkey, OH.LoadKey,oh.OrderKey,oh.ExternOrderKey  
      FROM Orders OH (NOLOCK)  
      WHERE LoadKey = @c_loadkey   
   END  
   ELSE IF EXISTS (SELECT 1 FROM Orders WITH (NOLOCK) WHERE orderkey = @c_loadkey)  
   BEGIN
      INSERT INTO #TMP_LoadOH11 (storerkey, loadkey, Orderkey,ExtOrdKey)  
      SELECT OH.Storerkey, OH.LoadKey,oh.OrderKey,oh.ExternOrderKey  
      FROM Orders OH (NOLOCK)  
      WHERE orderkey = @c_loadkey   
   END  
   
   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR       
   SELECT DISTINCT Storerkey,loadkey,Orderkey,ExtOrdKey  
   FROM   #TMP_LoadOH11     
    
   OPEN CUR_RESULT
   
   FETCH NEXT FROM CUR_RESULT INTO @c_getstorerkey,@c_getLoadkey,@c_getOrderkey,@c_getExtOrderkey
   
   WHILE @@FETCH_STATUS <> -1    
   BEGIN
   
      INSERT INTO #TMP_SMBLOAD11  
      (  
      -- rowid -- this column value is auto-generated  
          Orderkey,  
          loadkey,  
          C_Company,  
          SKU,  
          SDESCR,  
          Lottable04,  
          PQty,  
          CaseCnt,  
          ExtOrdKey,    
          consigneekey,  
          C_Contact1,  
          C_Phone1,  
          CaseCnt2,  
          PCS ,  
          STDNETWGT,  
          StdCube,  
          ST_company,
          C_Address1,
          F_Address1  
      )  
      SELECT Orders.orderkey,Orders.loadkey,Orders.c_company,  
             orderdetail.Sku,  
             RTRIM(sku.DESCR),  
             CONVERT(NVARCHAR(10),lot.lottable04,121) AS lottable04,  
             Sum(pickdetail.qty),  
             CASE WHEN L.locationtype <> 'PICK' THEN SUM(pickdetail.qty) ELSE 0 END / pack.CaseCnt,  
             Orders.ExternOrderKey,Orders.consigneekey,  
             ISNULL(RTRIM(Orders.c_Contact1), ''),  
             ISNULL(RTRIM(Orders.C_Phone1), '') ,  
             ISNULL((pack.CaseCnt + CAST(isnull(sku.busr3,0) as int)),0),  
             CASE WHEN L.locationtype<>'PICK' THEN SUM(pickdetail.qty) ELSE 0 END % CAST(pack.casecnt as int) +  
             CASE WHEN L.locationtype='PICK' THEN SUM(pickdetail.qty) ELSE 0 END,  
             cast(Sum(pickdetail.qty)*sku.StdGrossWgt as decimal(9,4)),  
             case when sku.[Cube]>0 then Sum(pickdetail.qty) *sku.StdCube else Sum(pickdetail.qty) *sku.StdCube  end,  
             --storer.company,
             N'小小运动馆',
             ISNULL(C_Address1,''),
             --ISNULL(F.Address1,'')  
             N'江苏省昆山市花桥镇锋星路1000号2号库'
      FROM Orders WITH (nolock)  
      LEFT JOIN orderdetail orderdetail  WITH  (nolock) on orderdetail.orderkey = Orders.orderkey   
      LEFT JOIN storer storer  WITH (nolock) on Orders.storerkey = storer.storerkey   
      JOIN sku sku WITH (nolock) on orderdetail.storerkey=sku.storerkey and orderdetail.sku = sku.sku   
      JOIN pack pack  WITH (nolock) on pack.packkey = sku.packkey   
      LEFT JOIN PickDetail pickdetail  WITH  (nolock) on pickdetail.OrderKey=orderdetail.OrderKey and pickdetail.OrderLineNumber=orderdetail.OrderLineNumber  
      LEFT JOIN LotAttribute lot  WITH (nolock) on pickdetail.Lot=lot.Lot  
      JOIN LOC L WITH (NOLOCK) ON L.loc = pickdetail.loc  
      JOIN FACILITY F WITH (NOLOCK) ON F.facility = Orders.facility  
      WHERE Orders.StorerKey = @c_getstorerkey  
      AND Orders.LoadKey = @c_getLoadkey  
      AND Orders.Orderkey = @c_getOrderkey  
      GROUP BY Orders.orderkey,Orders.loadkey,Orders.c_company,  
               orderdetail.Sku,  
               RTRIM(sku.DESCR),  
               CONVERT(NVARCHAR(10),lot.lottable04,121) ,  
          --   Sum(pickdetail.qty),  
               (pack.CaseCnt + CAST(isnull(sku.busr3,0) as int)),  
               Orders.ExternOrderKey,  
               ISNULL(RTRIM(Orders.c_Contact1), ''),  
               ISNULL(RTRIM(Orders.C_Phone1), '') ,L.locationtype,pack.CaseCnt,Orders.consigneekey,  
               sku.StdGrossWgt,sku.[cube],sku.StdCube,
               --storer.company,
               ISNULL(C_Address1,'')
               --ISNULL(F.Address1,'')  
      ORDER BY Orders.orderkey,Orders.loadkey,Orders.ExternOrderKey,orderdetail.Sku  
  
      
      FETCH NEXT FROM CUR_RESULT INTO @c_getstorerkey,@c_getLoadkey,@c_getOrderkey ,@c_getExtOrderkey   
   END     
   CLOSE CUR_RESULT
   DEALLOCATE CUR_RESULT
       
   SELECT  
      ts.Orderkey,  
      CAST(ts.StdCube as decimal(10,2)) as StdCube,  
      ts.STDNETWGT,  
      ts.C_Contact1,  
      ts.C_Phone1,  
      ts.C_Company,  
      ts.loadkey,  
      ts.Lottable04,  
      ts.SKU,  
      ts.ExtOrdKey,    
      ts.PQty,  
      ts.ST_company,  
      ts.consigneekey,  
      ts.CaseCnt2,  
      ts.PCS,  
      ts.SDESCR,  
      FLOOR(ts.CaseCnt) as CaseCnt,ts.c_address1,ts.F_address1,
      ROW_Number() OVER(PARTITION BY ts.Orderkey ORDER BY ts.Orderkey )  AS seqno
   FROM #TMP_SMBLOAD11 AS ts  
   ORDER BY ts.loadkey,ts.Orderkey,ts.ExtOrdKey,ts.SKU  
      
QUIT_SP:  
      
END  



GO