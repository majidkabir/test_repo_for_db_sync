SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_shipping_manifest_by_load_16                    */
/* Creation Date: 2020-04-14                                             */
/* Copyright: IDS                                                        */
/* Written by:                                                           */
/*                                                                       */
/* Purpose:WMS-12761 [CN] SUMEI_POD_CR                                   */
/*                                                                       */
/* Called By: r_shipping_manifest_by_load_16                             */
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
CREATE PROC [dbo].[isp_shipping_manifest_by_load_16]
         (  @c_loadkey    NVARCHAR(10),
            @c_Orderkey   NVARCHAR(10) = '' 
         )
      
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @c_storerkey       NVARCHAR(10)
          ,@n_NoOfLine        INT
          ,@c_getstorerkey    NVARCHAR(10)
          ,@c_getLoadkey      NVARCHAR(20)
          ,@c_getOrderkey     NVARCHAR(20)
          ,@c_getExtOrderkey  NVARCHAR(50)
          ,@n_MaxLineno       INT = 13
          ,@n_MaxRec          INT
          ,@n_CurrentRec      INT

  CREATE TABLE #TMP_LoadOH16(
          rowid           int identity(1,1),
          storerkey       NVARCHAR(20) NULL,
          loadkey         NVARCHAR(50) NULL,
          Orderkey        NVARCHAR(10) NULL,
          ExtOrdKey       NVARCHAR(50) NULL)             
    
   CREATE TABLE #TMP_SMBLOAD16 (
          rowid           int identity(1,1),
          Orderkey        NVARCHAR(20)  NULL,
          loadkey         NVARCHAR(50)  NULL,
          C_Company       NVARCHAR(45)  NULL,
          SKU             NVARCHAR(20)  NULL,
          SDESCR          NVARCHAR(150) NULL,
          FUDF07          NVARCHAR(30)  NULL,
          TTLQty          INT NULL DEFAULT(0),
          CaseCnt         FLOAT NULL DEFAULT(0),
          ExtOrdKey       NVARCHAR(50) NULL,  
          consigneekey    NVARCHAR(45) NULL,
          Salesman        NVARCHAR(30) NULL,
          C_Phone1        NVARCHAR(45) NULL,
          CaseCnt2        INT NULL DEFAULT(0),
          PCS             INT NULL DEFAULT(0),
          STDNETWGT       FLOAT NULL,
          StdCube         FLOAT NULL,
          Buyerpo         NVARCHAR(20) NULL,
          altsku          NVARCHAR(20) NULL,
          UPC             NVARCHAR(20) NULL,
          ST_Address      NVARCHAR(45) NULL,
          C_Address1      NVARCHAR(45) NULL,
          CLong           NVARCHAR(80) NULL,
          ST_Notes1       NVARCHAR(80) NULL, 
          ST_Phone1       NVARCHAR(45) NULL,
          ST_Fax1         NVARCHAR(45) NULL,
          ST_Notes2       NVARCHAR(80) NULL,
          c_contact1      NVARCHAR(45) NULL,
          OrdLineNo       NVARCHAR(5)  NULL,    
          facility        NVARCHAR(50) NULL     
          )   

   IF @c_Orderkey = NULL SET @c_Orderkey = ''   
   
   -- SET @n_NoOfLine = 6
   
   --WL03 
   --SELECT TOP 1 @c_storerkey = OH.Storerkey
   --FROM ORDERS OH (NOLOCK)
   --WHERE Loadkey = @c_loadkey OR orderkey =  @c_loadkey
   
   --WL01 Start
   IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE Loadkey = @c_loadkey AND @c_Orderkey <> '')
   BEGIN
      IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE Loadkey = @c_loadkey AND Orderkey = @c_Orderkey)
      BEGIN
         INSERT INTO #TMP_LoadOH16 (storerkey, loadkey, Orderkey,ExtOrdKey)
         SELECT OH.Storerkey, OH.LoadKey,oh.OrderKey,oh.ExternOrderKey --WL03
         FROM ORDERS OH (NOLOCK)
         WHERE LoadKey = @c_loadkey AND Orderkey = @c_Orderkey
      END
   END
   --WL01 End
   ELSE IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE Loadkey = @c_loadkey AND @c_Orderkey = '') 
   BEGIN
      INSERT INTO #TMP_LoadOH16 (storerkey, loadkey, Orderkey,ExtOrdKey)
      SELECT OH.Storerkey, OH.LoadKey,oh.OrderKey,oh.ExternOrderKey --WL03
      FROM ORDERS OH (NOLOCK)
      WHERE LoadKey = @c_loadkey
   END
   ELSE IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE orderkey = @c_loadkey AND @c_Orderkey = '') 
   BEGIN
      INSERT INTO #TMP_LoadOH16 (storerkey, loadkey, Orderkey,ExtOrdKey)
      SELECT OH.Storerkey, OH.LoadKey,oh.OrderKey,oh.ExternOrderKey 
      FROM ORDERS OH (NOLOCK)
      WHERE orderkey = @c_loadkey 
   END

   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT Storerkey,loadkey,Orderkey,ExtOrdKey
   FROM   #TMP_LoadOH16 
   WHERE loadkey = @c_loadkey OR orderkey =  @c_loadkey
   
   OPEN CUR_RESULT   
   
   FETCH NEXT FROM CUR_RESULT INTO @c_getstorerkey,@c_getLoadkey,@c_getOrderkey,@c_getExtOrderkey    
   
   WHILE @@FETCH_STATUS <> -1  
   BEGIN    
      
     INSERT INTO #TMP_SMBLOAD16
     (
      -- rowid -- this column value is auto-generated
             Orderkey,
             loadkey,
             C_Company,
             SKU,
             SDESCR,
             FUDF07,
             TTLQty,
             CaseCnt,
             ExtOrdKey,  
             consigneekey,
             Salesman,
             C_Phone1,
             CaseCnt2,
             PCS,
             STDNETWGT,
             StdCube,
             Buyerpo,
             altsku,
             UPC,
             ST_Address,
             C_Address1,
             CLong,
             ST_Notes1, 
             ST_Phone1,
             ST_Fax1,
             ST_Notes2,
             c_contact1,
             OrdLineNo,        
             facility          
     )
      SELECT orders.orderkey,orders.loadkey,orders.c_company,
             CASE WHEN LEN(Orderdetail.SKU)=12 THEN LEFT(LTRIM(RTRIM(Orderdetail.Sku)),5)+'-'+SUBSTRING(LTRIM(RTRIM(orderdetail.SKU)),6,5)
                       +'-'+RIGHT(LTRIM(RTRIM(Orderdetail.SKU)),2) ELSE Orderdetail.Sku END AS SKU,           
             RTRIM(sku.DESCR),
             ISNULL(f.Descr,'') AS FUDF07,
             Sum(pickdetail.qty),
             pack.CaseCnt ,
             orders.ExternOrderKey,orders.consigneekey,
             ISNULL(RTRIM(orders.Salesman), ''),
             ISNULL(RTRIM(orders.C_Phone1), '') ,
             (Sum(pickdetail.qty)/pack.CaseCnt),
             CASE WHEN L.locationtype<>'PICK' THEN SUM(pickdetail.qty) ELSE 0 END % CAST(pack.casecnt as int) +
                                                   CASE WHEN L.locationtype='PICK' THEN SUM(pickdetail.qty) ELSE 0 END as PCS,
                                                   cast(Sum(pickdetail.qty)*sku.StdGrossWgt as decimal(20,4)) as STDNETWGT,    
                                                   case when Sum(pickdetail.qty)>CAST(pack.casecnt as int) then (((Sum(pickdetail.qty)/CAST(pack.casecnt as int)) *sku.Cube) + 
                                                   ((Sum(pickdetail.qty)%CAST(pack.casecnt as int)) *sku.StdCube)) 
                                                   else Sum(pickdetail.qty) *sku.StdCube  end as StdCube,
             orders.BuyerPO,SUBSTRING(SKU.altsku,LEN(SKU.altsku)-12,13),
             ISNULL(orderdetail.manufacturerSKU ,'000000000000'),
             ISNULL(storer.Address1,''),ISNULL(orders.c_Address1,''), ISNULL(c.long,''),
             ISNULL(storer.notes1,''),ISNULL(storer.phone1,''),ISNULL(storer.fax1,''),
             ISNULL(orders.notes2,''),ISNULL(orders.c_contact1,''),
             Orderdetail.OrderLineNumber,    
             --CASE WHEN Orders.facility ='BTS01' THEN N'上海配送中心' 
             --WHEN Orders.facility ='PY06' THEN  N'广州配送中心' 
             --WHEN Orders.facility ='647' THEN N'北京配送中心' WHEN Orders.facility ='CD01' THEN N'成都配送中心' 
             --WHEN Orders.facility ='WH01' THEN N'武汉配送中心' ELSE '' END AS facility  
             ISNULL(C1.long,'') as facility  
      FROM Orders orders  WITH (nolock)
      LEFT JOIN orderdetail orderdetail  WITH  (nolock) on orderdetail.orderkey = orders.orderkey 
      LEFT JOIN storer storer  WITH (nolock) on orders.storerkey = storer.storerkey 
      JOIN sku sku WITH (nolock) on orderdetail.storerkey=sku.storerkey and orderdetail.sku = sku.sku 
      JOIN pack pack  WITH (nolock) on pack.packkey = sku.packkey 
      LEFT JOIN PickDetail pickdetail  WITH  (nolock) on pickdetail.OrderKey=orderdetail.OrderKey 
                                                     and pickdetail.OrderLineNumber=orderdetail.OrderLineNumber
      JOIN Facility F WITH (NOLOCK) ON F.Facility = orders.Facility
      JOIN LOC L WITH (NOLOCK) ON L.loc = pickdetail.loc
      OUTER APPLY (SELECT TOP 1 CL.Long FROM CODELKUP CL WITH (NOLOCK)                        
                   WHERE orders.C_State = CL.Code AND CL.listname='NVREGION'                  
                   ORDER BY CASE WHEN CL.Storerkey = ORDERS.Storerkey THEN 1 ELSE 2 END) AS C    
      OUTER APPLY (SELECT TOP 1 CL1.Long FROM CODELKUP CL1 WITH (NOLOCK)                        
                   WHERE orders.facility = CL1.Code AND CL1.listname='DCNAME' AND CL1.Storerkey = ORDERS.Storerkey                  
                   ORDER BY CASE WHEN CL1.Storerkey = ORDERS.Storerkey THEN 1 ELSE 2 END) AS C1                                       
      WHERE orders.StorerKey = @c_getstorerkey
      AND orders.LoadKey = @c_getLoadkey
      AND orders.Orderkey = @c_getOrderkey
      AND pack.CaseCnt <> 0 
      GROUP BY orders.orderkey,orders.loadkey,orders.c_company,
               CASE WHEN LEN(Orderdetail.SKU)=12 THEN LEFT(LTRIM(RTRIM(Orderdetail.Sku)),5)+'-'+SUBSTRING(LTRIM(RTRIM(orderdetail.SKU)),6,5)
                         +'-'+RIGHT(LTRIM(RTRIM(Orderdetail.SKU)),2) ELSE Orderdetail.Sku END,         
               RTRIM(sku.DESCR),
               ISNULL(f.Descr,''),
               pack.CaseCnt ,
               orders.ExternOrderKey,orders.consigneekey,
               ISNULL(RTRIM(orders.Salesman), ''),
               ISNULL(RTRIM(orders.C_Phone1), ''), l.LocationType, SKU.STDGROSSWGT, SKU.[Cube], SKU.STDCUBE,
               orders.BuyerPO,SUBSTRING(SKU.altsku,LEN(SKU.altsku)-12,13),
               ISNULL(orderdetail.manufacturerSKU ,'000000000000'),
               ISNULL(storer.Address1,''),ISNULL(orders.c_Address1,''), ISNULL(c.long,''),
               ISNULL(storer.notes1,''),ISNULL(storer.phone1,''),ISNULL(storer.fax1,''),
               ISNULL(orders.notes2,''),ISNULL(orders.c_contact1,''), orderdetail.Sku,
               Orderdetail.OrderLineNumber,     
               ISNULL(C1.long,'')
               --CASE WHEN Orders.facility ='BTS01' THEN N'上海配送中心' 
               --WHEN Orders.facility ='PY06' THEN  N'广州配送中心' 
               --WHEN Orders.facility ='647' THEN N'北京配送中心' WHEN Orders.facility ='CD01' THEN N'成都配送中心' 
               --WHEN Orders.facility ='WH01' THEN N'武汉配送中心' ELSE '' END   
      ORDER BY orders.orderkey,orders.loadkey,orders.ExternOrderKey,orderdetail.Sku
   
      FETCH NEXT FROM CUR_RESULT INTO @c_getstorerkey,@c_getLoadkey,@c_getOrderkey ,@c_getExtOrderkey 
   END   
         
   SELECT Orderkey,
          SUM(StdCube),
          SUM(STDNETWGT),
          FUDF07,
          C_Phone1,
          C_Company,
          loadkey,
          Salesman,
          SKU,
          ExtOrdKey,  
          SUM(TTLQty),
          ST_Address,
          consigneekey,
          SUM(CaseCnt2),
          SUM(ISNULL(PCS,0)) AS PCS,
          SDESCR,
          CaseCnt,      
          Buyerpo,
          altsku,
          UPC,
          C_Address1,
          CLong,
          ST_Notes1, 
          ST_Phone1,
          ST_Fax1,
          ST_Notes2,
          c_contact1,
          facility        
   FROM   #TMP_SMBLOAD16 AS ts
   GROUP BY Orderkey,
          FUDF07,
          C_Phone1,
          C_Company,
          loadkey,
          Salesman,
          SKU,
          ExtOrdKey,  
          ST_Address,
          consigneekey,
          SDESCR,
          CaseCnt,      
          Buyerpo,
          altsku,
          UPC,
          C_Address1,
          CLong,
          ST_Notes1, 
          ST_Phone1,
          ST_Fax1,
          ST_Notes2,
          c_contact1,
          ts.OrdLineNo,
          facility       
   ORDER BY ts.loadkey, ts.ExtOrdKey, ts.Orderkey, ts.OrdLineNo
    
QUIT_SP:
    
END


GO