SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_shipping_manifest_by_load_17                    */
/* Creation Date: 2021-08-09                                             */
/* Copyright: IDS                                                        */
/* Written by: Mingle                                                    */
/*                                                                       */
/* Purpose:WMS-17652 - [CN] BlueDash_POD REPORT_NEW                      */
/*                                                                       */
/* Called By: r_shipping_manifest_by_load_17                             */
/*                                                                       */
/* PVCS Version: 1.1                                                     */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author  Ver   Purposes                                   */
/* 22-Sep-2021  LZG     1.1   JSM-19869 - Extended field length (ZG01)   */
/*************************************************************************/
CREATE PROC [dbo].[isp_shipping_manifest_by_load_17]
         (  @c_loadkey    NVARCHAR(10),
            @c_Orderkey   NVARCHAR(10) = '', --WL01
            @c_RPTTYPE    NVARCHAR(10) = '1' --CS01
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
          ,@c_getExtOrderkey  NVARCHAR(20)
          ,@n_MaxLineno       INT = 13
          ,@n_MaxRec          INT
          ,@n_CurrentRec      INT

  CREATE TABLE #TMP_LoadOH17(
          rowid           int identity(1,1),
          storerkey       NVARCHAR(20) NULL,
          loadkey         NVARCHAR(50) NULL,
          Orderkey        NVARCHAR(10) NULL,
          ExtOrdKey       NVARCHAR(50) NULL)           
    
   CREATE TABLE #TMP_SMBLOAD17 (
          rowid           int identity(1,1),
          Orderkey        NVARCHAR(20)  NULL,
          loadkey         NVARCHAR(50)  NULL,
          C_Company       NVARCHAR(45)  NULL,
          SKU             NVARCHAR(20)  NULL,
          SDESCR          NVARCHAR(150) NULL,
          FUDF07          NVARCHAR(30)  NULL,
          TTLQty          INT NULL DEFAULT(0),
          CaseCnt         FLOAT NULL DEFAULT(0),
          ExtOrdKey       NVARCHAR(50) NULL,    -- ZG01
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
          facility        NVARCHAR(50) NULL,   
          SSUSR1          NVARCHAR(20) NULL,    
          SSUSR2          NVARCHAR(20) NULL,    
          SSUSR3          NVARCHAR(20) NULL,    
          SSUSR4          NVARCHAR(20) NULL,
          ST_B_company       NVARCHAR(50) NULL     
          )   

   IF @c_Orderkey = NULL SET @c_Orderkey = ''   
   
   -- SET @n_NoOfLine = 6
    
   --SELECT TOP 1 @c_storerkey = OH.Storerkey
   --FROM ORDERS OH (NOLOCK)
   --WHERE Loadkey = @c_loadkey OR orderkey =  @c_loadkey
   
   IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE Loadkey = @c_loadkey AND @c_Orderkey <> '')
   BEGIN
      IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE Loadkey = @c_loadkey AND Orderkey = @c_Orderkey)
      BEGIN
         INSERT INTO #TMP_LoadOH17 (storerkey, loadkey, Orderkey,ExtOrdKey)
         SELECT OH.Storerkey, OH.LoadKey,oh.OrderKey,oh.ExternOrderKey
         FROM ORDERS OH (NOLOCK)
         JOIN STORER S WITH (NOLOCK) ON S.StorerKey = OH.StorerKey
         WHERE LoadKey = @c_loadkey AND Orderkey = @c_Orderkey
      END
   END
   ELSE IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE Loadkey = @c_loadkey AND @c_Orderkey = '') 
   BEGIN
      INSERT INTO #TMP_LoadOH17 (storerkey, loadkey, Orderkey,ExtOrdKey)
      SELECT OH.Storerkey, OH.LoadKey,oh.OrderKey,oh.ExternOrderKey 
      FROM ORDERS OH (NOLOCK)
      WHERE LoadKey = @c_loadkey
   END
   ELSE IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE orderkey = @c_loadkey AND @c_Orderkey = '') 
   BEGIN
      INSERT INTO #TMP_LoadOH17 (storerkey, loadkey, Orderkey,ExtOrdKey)
      SELECT OH.Storerkey, OH.LoadKey,oh.OrderKey,oh.ExternOrderKey 
      FROM ORDERS OH (NOLOCK)
      WHERE orderkey = @c_loadkey 
   END

   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT Storerkey,loadkey,Orderkey,ExtOrdKey
   FROM   #TMP_LoadOH17   
   WHERE loadkey = @c_loadkey OR orderkey =  @c_loadkey
   
   OPEN CUR_RESULT   
   
   FETCH NEXT FROM CUR_RESULT INTO @c_getstorerkey,@c_getLoadkey,@c_getOrderkey,@c_getExtOrderkey    
   
   WHILE @@FETCH_STATUS <> -1  
   BEGIN   	
   	
     INSERT INTO #TMP_SMBLOAD17
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
             facility,         
             SSUSR1,           
             SSUSR2,            
             SSUSR3,           
             SSUSR4,                         
             ST_B_company                      
     )
      SELECT orders.orderkey,orders.loadkey,orders.c_company,
             CASE WHEN LEN(Orderdetail.SKU)=17 THEN LEFT(LTRIM(RTRIM(Orderdetail.Sku)),5)+'-'+SUBSTRING(LTRIM(RTRIM(orderdetail.SKU)),6,5)
                       +'-'+RIGHT(LTRIM(RTRIM(Orderdetail.SKU)),2) ELSE Orderdetail.Sku END AS SKU,           
             RTRIM(sku.DESCR),
             ISNULL(f.Descr,'') AS FUDF07,
             Sum(pickdetail.qty),
             pack.CaseCnt ,--SUM(pickdetail.qty) ELSE 0 END/pack.CaseCnt,
             orders.ExternOrderKey,orders.consigneekey,
             ISNULL(RTRIM(orders.Salesman), ''),
             ISNULL(RTRIM(orders.C_Phone1), '') ,
             (Sum(pickdetail.qty)/pack.CaseCnt),--ISNULL((pack.CaseCnt + CAST(sku.busr3 as int)),0) as casecnt2,
             CASE WHEN L.locationtype<>'PICK' THEN SUM(pickdetail.qty) ELSE 0 END % CAST(pack.casecnt as int) +
                                                   CASE WHEN L.locationtype='PICK' THEN SUM(pickdetail.qty) ELSE 0 END as PCS,
                                                   cast(Sum(pickdetail.qty)*sku.StdGrossWgt as decimal(20,4)) as STDNETWGT,    
                                                   case when Sum(pickdetail.qty)>CAST(pack.casecnt as int) then (((Sum(pickdetail.qty)/CAST(pack.casecnt as int)) *sku.Cube) + 
                                                   ((Sum(pickdetail.qty)%CAST(pack.casecnt as int)) *sku.StdCube)) 
                                                   else Sum(pickdetail.qty) *sku.StdCube  end as StdCube,
             orders.BuyerPO,SUBSTRING(SKU.altsku,LEN(SKU.altsku)-17,13),
             ISNULL(orderdetail.manufacturerSKU ,'000000000000'),
             ISNULL(storer.Address1,''),ISNULL(orders.c_Address1,''), ISNULL(c.long,''),
             ISNULL(storer.notes1,''),ISNULL(storer.phone1,''),ISNULL(storer.fax1,''),
             ISNULL(orders.notes2,''),ISNULL(orders.c_contact1,''),
             Orderdetail.OrderLineNumber,     --WL01
             CASE WHEN Orders.facility ='BTS01' THEN N'Î£â••Ã¨Âµâ•¡â•–Î˜Ã Ã¬Î˜Ã‡Ã¼Î£â••Â¡Ïƒâ”Ã¢' 
                  WHEN Orders.facility ='PY06'  THEN N'Ïƒâ•£â”Ïƒâ•–â‚§Î˜Ã Ã¬Î˜Ã‡Ã¼Î£â••Â¡Ïƒâ”Ã¢' 
                  WHEN Orders.facility ='647'   THEN N'ÏƒÃ®Ã¹Î£â•‘Â¼Î˜Ã Ã¬Î˜Ã‡Ã¼Î£â••Â¡Ïƒâ”Ã¢' 
                  WHEN Orders.facility ='CD01'  THEN N'ÂµÃªÃ‰Î˜Ã¢â•œÎ˜Ã Ã¬Î˜Ã‡Ã¼Î£â••Â¡Ïƒâ”Ã¢' 
                  WHEN Orders.facility ='WH01'  THEN N'ÂµÂ¡ÂªÂµâ–’Ã«Î˜Ã Ã¬Î˜Ã‡Ã¼Î£â••Â¡Ïƒâ”Ã¢' 
                  ELSE '' END  + ' (' + ISNULL(CL.Short,'') + ')' AS facility    
             ,ISNULL(sku.susr1,''), ISNULL(sku.SUSR2,''),ISNULL(sku.SUSR3,''),ISNULL(sku.SUSR4,'')
             ,ISNULL(storer.B_Company,'')
      FROM Orders orders  WITH (nolock)
      LEFT JOIN orderdetail orderdetail  WITH  (nolock) on orderdetail.orderkey = orders.orderkey 
      LEFT JOIN storer storer  WITH (nolock) on orders.storerkey = storer.storerkey 
      JOIN sku sku WITH (nolock) on orderdetail.storerkey=sku.storerkey and orderdetail.sku = sku.sku 
      JOIN pack pack  WITH (nolock) on pack.packkey = sku.packkey 
      LEFT JOIN PickDetail pickdetail  WITH  (nolock) on pickdetail.OrderKey=orderdetail.OrderKey 
                                                     and pickdetail.OrderLineNumber=orderdetail.OrderLineNumber
      JOIN Facility F WITH (NOLOCK) ON F.Facility = orders.Facility
      JOIN LOC L WITH (NOLOCK) ON L.loc = pickdetail.loc
      --LEFT JOIN Codelkup AS c (NOLOCK) ON orders.C_State=c.Code AND c.listname='NVREGION'
	   --                                and orders.StorerKey = c.Storerkey
      OUTER APPLY (SELECT TOP 1 CL.Long FROM CODELKUP CL WITH (NOLOCK)                        
                   WHERE orders.C_State = CL.Code AND CL.listname='NVREGION'                  
                   ORDER BY CASE WHEN CL.Storerkey = ORDERS.Storerkey THEN 1 ELSE 2 END) AS C             
      LEFT JOIN CODELKUP CL WITH (NOLOCK) ON CL.LISTNAME = 'NIVPODRPT' AND CL.Storerkey = ORDERS.StorerKey AND CL.Code = ORDERS.StorerKey                                
      WHERE orders.StorerKey = @c_getstorerkey
      AND orders.LoadKey = @c_getLoadkey
      AND orders.Orderkey = @c_getOrderkey
      AND pack.CaseCnt <> 0 
      /*Group by orders.orderkey,orders.loadkey,orders.c_company,
               CASE WHEN LEN(Orderdetail.SKU)=17 THEN LEFT(LTRIM(RTRIM(Orderdetail.Sku)),5)+'-'+SUBSTRING(LTRIM(RTRIM(orderdetail.SKU)),6,5)
               +'-'+RIGHT(LTRIM(RTRIM(Orderdetail.SKU)),2) ELSE Orderdetail.Sku END,
               RTRIM(sku.DESCR),
               ISNULL(f.Descr,''),
               orders.ExternOrderKey,orders.consigneekey,
               ISNULL(RTRIM(orders.Salesman), ''),
               ISNULL(RTRIM(orders.C_Phone1), '') ,
               ISNULL((pack.CaseCnt + CAST(sku.busr3 as int)),0),
               orders.BuyerPO,SUBSTRING(SKU.altsku,LEN(SKU.altsku)-17,13),
               ISNULL(orderdetail.manufacturerSKU ,'000000000000'),
               ISNULL(storer.Address1,''),ISNULL(orders.c_Address1,''), ISNULL(c.long,''),
               ISNULL(storer.notes1,''),ISNULL(storer.phone1,''),ISNULL(storer.fax1,'')
               ,L.locationtype,pack.casecnt,sku.StdGrossWgt,sku.[stdcube],sku.[cube],orderdetail.sku
               ,ISNULL(orders.notes2,''),ISNULL(orders.c_contact1,''), Orderdetail.OrderLineNumber,
               CASE WHEN Orders.facility ='BTS01' THEN N'Î£â••Ã¨Âµâ•¡â•–Î˜Ã Ã¬Î˜Ã‡Ã¼Î£â••Â¡Ïƒâ”Ã¢' 
               WHEN Orders.facility ='PY06' THEN  N'Ïƒâ•£â”Ïƒâ•–â‚§Î˜Ã Ã¬Î˜Ã‡Ã¼Î£â••Â¡Ïƒâ”Ã¢' WHEN Orders.facility ='647' THEN N'ÏƒÃ®Ã¹Î£â•‘Â¼Î˜Ã Ã¬Î˜Ã‡Ã¼Î£â••Â¡Ïƒâ”Ã¢'
               WHEN Orders.facility ='CD01' THEN N'ÂµÃªÃ‰Î˜Ã¢â•œÎ˜Ã Ã¬Î˜Ã‡Ã¼Î£â••Â¡Ïƒâ”Ã¢' WHEN Orders.facility ='WH01' THEN N'ÂµÂ¡ÂªÂµâ–’Ã«Î˜Ã Ã¬Î˜Ã‡Ã¼Î£â••Â¡Ïƒâ”Ã¢' ELSE '' END   */
      GROUP BY orders.orderkey,orders.loadkey,orders.c_company,
               CASE WHEN LEN(Orderdetail.SKU)=17 THEN LEFT(LTRIM(RTRIM(Orderdetail.Sku)),5)+'-'+SUBSTRING(LTRIM(RTRIM(orderdetail.SKU)),6,5)
                         +'-'+RIGHT(LTRIM(RTRIM(Orderdetail.SKU)),2) ELSE Orderdetail.Sku END,         
               RTRIM(sku.DESCR),
               ISNULL(f.Descr,''),
               pack.CaseCnt ,--SUM(pickdetail.qty) ELSE 0 END/pack.CaseCnt,
               orders.ExternOrderKey,orders.consigneekey,
               ISNULL(RTRIM(orders.Salesman), ''),
               ISNULL(RTRIM(orders.C_Phone1), ''), l.LocationType, SKU.STDGROSSWGT, SKU.[Cube], SKU.STDCUBE,
               orders.BuyerPO,SUBSTRING(SKU.altsku,LEN(SKU.altsku)-17,13),
               ISNULL(orderdetail.manufacturerSKU ,'000000000000'),
               ISNULL(storer.Address1,''),ISNULL(orders.c_Address1,''), ISNULL(c.long,''),
               ISNULL(storer.notes1,''),ISNULL(storer.phone1,''),ISNULL(storer.fax1,''),
               ISNULL(orders.notes2,''),ISNULL(orders.c_contact1,''), orderdetail.Sku,
               Orderdetail.OrderLineNumber,     
               CASE WHEN Orders.facility ='BTS01' THEN N'Î£â••Ã¨Âµâ•¡â•–Î˜Ã Ã¬Î˜Ã‡Ã¼Î£â••Â¡Ïƒâ”Ã¢' 
                    WHEN Orders.facility ='PY06'  THEN N'Ïƒâ•£â”Ïƒâ•–â‚§Î˜Ã Ã¬Î˜Ã‡Ã¼Î£â••Â¡Ïƒâ”Ã¢' 
                    WHEN Orders.facility ='647'   THEN N'ÏƒÃ®Ã¹Î£â•‘Â¼Î˜Ã Ã¬Î˜Ã‡Ã¼Î£â••Â¡Ïƒâ”Ã¢' 
                    WHEN Orders.facility ='CD01'  THEN N'ÂµÃªÃ‰Î˜Ã¢â•œÎ˜Ã Ã¬Î˜Ã‡Ã¼Î£â••Â¡Ïƒâ”Ã¢' 
                    WHEN Orders.facility ='WH01'  THEN N'ÂµÂ¡ÂªÂµâ–’Ã«Î˜Ã Ã¬Î˜Ã‡Ã¼Î£â••Â¡Ïƒâ”Ã¢' 
                    ELSE '' END  + ' (' + ISNULL(CL.Short,'') + ')'  
               ,ISNULL(sku.susr1,''), ISNULL(sku.SUSR2,''),ISNULL(sku.SUSR3,''),ISNULL(sku.SUSR4,'')
               ,ISNULL(storer.B_Company,'')       
      ORDER BY orders.orderkey,orders.loadkey,orders.ExternOrderKey,orderdetail.Sku
   
      FETCH NEXT FROM CUR_RESULT INTO @c_getstorerkey,@c_getLoadkey,@c_getOrderkey ,@c_getExtOrderkey 
   END   
   		
   --SELECT Orderkey,
   --       StdCube,
   --       STDNETWGT,
   --       FUDF07,
   --       C_Phone1,
   --       C_Company,
   --       loadkey,
   --       Salesman,
   --       SKU,
   --       ExtOrdKey,  
   --       TTLQty,
   --       ST_Address,
   --       consigneekey,
   --       CaseCnt2,
   --       ISNULL(PCS,0) AS PCS,
   --       SDESCR,
   --       CaseCnt,      
   --       Buyerpo,
   --       altsku,
   --       UPC,
   --       C_Address1,
   --       CLong,
   --       ST_Notes1, 
   --       ST_Phone1,
   --       ST_Fax1,
   --       ST_Notes2,
   --       c_contact1
   --FROM   #TMP_SMBLOAD17 AS ts   
   ----WHERE ts.loadkey = @c_loadkey
   ----ORDER BY ts.loadkey,ts.Orderkey,ts.ExtOrdKey,ts.SKU         
   --ORDER BY ts.loadkey,ts.Orderkey,ts.ExtOrdKey,ts.OrdLineNo   
IF @c_RPTTYPE = '1'
BEGIN
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
          facility,
          ST_B_company        
   FROM   #TMP_SMBLOAD17 AS ts
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
          facility,
          ST_B_company        
   ORDER BY ts.loadkey, ts.ExtOrdKey, ts.Orderkey, ts.OrdLineNo
END
ELSE IF @c_RPTTYPE ='2'
BEGIN
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
          facility,
          SSUSR1,SSUSR2,SSUSR3,SSUSR4
   FROM   #TMP_SMBLOAD17 AS ts
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
          facility,        
          SSUSR1,SSUSR2,SSUSR3,SSUSR4
   ORDER BY ts.loadkey, ts.ExtOrdKey, ts.Orderkey, ts.OrdLineNo
END
    
QUIT_SP:
    
END


GO