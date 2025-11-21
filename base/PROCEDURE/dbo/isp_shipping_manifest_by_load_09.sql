SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/*************************************************************************/  
/* Stored Procedure: isp_shipping_manifest_by_load_09                    */  
/* Creation Date: 2018-05-16                                             */  
/* Copyright: IDS                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-4957 -CN WMS Remy POD                                    */  
/*                                                                       */  
/* Called By: r_shipping_manifest_by_load_09                             */  
/*                                                                       */  
/* PVCS Version: 1.1                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author  Ver   Purposes                                   */  
/* 30/11/2018   NJOW01  1.0   Fix - increase externorderkey field size   */
/*************************************************************************/  
CREATE PROC [dbo].[isp_shipping_manifest_by_load_09]  
         (  @c_loadkey    NVARCHAR(10)  
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
          ,@c_getExtOrderkey NVARCHAR(40)  
          ,@c_rptcompany1    NVARCHAR(100)   
          ,@c_rptcompany2    NVARCHAR(100)   
          ,@c_rptcompany3    NVARCHAR(100)   
          ,@c_rptcompany4    NVARCHAR(100)   
          ,@c_rptcompany5    NVARCHAR(100)  
          ,@c_rptcompany6    NVARCHAR(100)  
          ,@c_rptadd1        NVARCHAR(100)   
          ,@c_rptadd2        NVARCHAR(100)  
          ,@c_rpttel         NVARCHAR(100)   
          ,@c_rptfax         NVARCHAR(100)   
          ,@c_LabelName      NVARCHAR(50)  
          ,@c_LabelValue     NVARCHAR(150)  
            
  CREATE TABLE #TMP_LoadOH09(  
          rowid           int identity(1,1),  
          storerkey       NVARCHAR(20) NULL,  
          loadkey         NVARCHAR(50) NULL,  
          Orderkey        NVARCHAR(10) NULL,  
          ExtOrdKey       NVARCHAR(40) NULL)             
      
   CREATE TABLE #TMP_SMBLOAD09 (  
          rowid           int identity(1,1),  
          Orderkey        NVARCHAR(20)  NULL,  
          loadkey         NVARCHAR(50)  NULL,  
          ST_Company      NVARCHAR(45)  NULL,  
          SKU             NVARCHAR(20)  NULL,  
          SDESCR          NVARCHAR(150) NULL,  
          PUOM01          NVARCHAR(10)  NULL,  
          PUOM03          NVARCHAR(10)  NULL,  
          C_Address1      NVARCHAR(45)  NULL,  
          Lottable04      NVARCHAR(10)  NULL,  
          PQty            INT,  
          CaseCnt         FLOAT,  
          ExtOrdKey       NVARCHAR(40) NULL,    
          ORDDate         DATETIME ,  
          consigneekey    NVARCHAR(45) NULL,  
          C_Address2      NVARCHAR(45) NULL,  
          C_Address3      NVARCHAR(45) NULL,  
          C_Contact1      NVARCHAR(45) NULL,  
          C_Contact2      NVARCHAR(45) NULL,  
          C_Phone1        NVARCHAR(45) NULL,  
          C_Phone2        NVARCHAR(45) NULL,  
          BillToKey       NVARCHAR(20) NULL,  
          ST_notes1       NVARCHAR(150) NULL,  
          BuyerPO         NVARCHAR(30) NULL,  
          Lottable02      NVARCHAR(18) NULL,  
          Facility        NVARCHAR(10) NULL,  
          C_Address4      NVARCHAR(45) NULL,  
          OHNotes         NVARCHAR(150) NULL,  
          DeliveryDate    DATETIME ,  
          STDNETWGT       FLOAT NULL,  
          StdCube         FLOAT NULL,  
          rptremarks      NVARCHAR(120) NULL,  
          rptcompany1     NVARCHAR(100) NULL,  
          rptcompany2     NVARCHAR(100) NULL,  
          rptcompany3     NVARCHAR(100) NULL,  
          rptcompany4     NVARCHAR(100) NULL,  
          rptcompany5     NVARCHAR(100) NULL,  
          rptcompany6     NVARCHAR(100) NULL,  
        --  rptcompany7     NVARCHAR(100) NULL,  
          rptadd1         NVARCHAR(100) NULL,  
          rptadd2         NVARCHAR(100) NULL,  
          rpttel          NVARCHAR(100) NULL,  
          rptfax          NVARCHAR(100) NULL  
          )         
     
     
  -- SET @n_NoOfLine = 6  
  
  SET @c_rptcompany1 = ''     
  SET @c_rptcompany2 = ''     
  SET @c_rptcompany3 = ''     
  SET @c_rptcompany4 = ''     
  SET @c_rptcompany5 = ''    
  SET @c_rptcompany6 = ''     
  SET @c_rptadd1     = ''        
  SET @c_rptadd2     = ''         
  SET @c_rpttel      = ''        
  SET @c_rptfax      = ''          
     
  SELECT TOP 1 @c_storerkey = OH.Storerkey  
  FROM ORDERS OH (NOLOCK)  
  WHERE Loadkey = @c_loadkey  
  
  
  DECLARE CUR_LBL CURSOR LOCAL FORWARD_ONLY STATIC READ_ONLY FOR  
     SELECT CL.code2  
          , CL.Notes  
     FROM ORDERS OH WITH (NOLOCK)  
     JOIN CODELKUP    CL WITH (NOLOCK) ON (CL.ListName = 'REMYCOM1'  
                                       AND CL.storerkey = OH.storerkey  
               AND CL.Code = OH.Facility)  
     
   WHERE OH. LoadKey = @c_loadkey   
     
   OPEN CUR_LBL  
  
   FETCH NEXT FROM CUR_LBL INTO @c_LabelName, @c_LabelValue  
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN    
      SET @c_rptcompany1   =  CASE WHEN @c_LabelName = '001'   THEN @c_LabelValue ELSE @c_rptcompany1   END   
      SET @c_rptcompany2   =  CASE WHEN @c_LabelName = '002'   THEN @c_LabelValue ELSE @c_rptcompany2   END   
      SET @c_rptcompany3   =  CASE WHEN @c_LabelName = '003'   THEN @c_LabelValue ELSE @c_rptcompany3   END  
      SET @c_rptcompany4   =  CASE WHEN @c_LabelName = '004'   THEN @c_LabelValue ELSE @c_rptcompany4   END   
      SET @c_rptcompany5   =  CASE WHEN @c_LabelName = '005'   THEN @c_LabelValue ELSE @c_rptcompany5   END   
      SET @c_rptcompany6   =  CASE WHEN @c_LabelName = '006'   THEN @c_LabelValue ELSE @c_rptcompany6   END   
      SET @c_rptadd1       =  CASE WHEN @c_LabelName = '007'   THEN @c_LabelValue ELSE @c_rptadd1   END   
      SET @c_rptadd2       =  CASE WHEN @c_LabelName = '008'   THEN @c_LabelValue ELSE @c_rptadd2   END   
      SET @c_rpttel        =  CASE WHEN @c_LabelName = '009'   THEN @c_LabelValue ELSE @c_rpttel   END   
      SET @c_rptfax        =  CASE WHEN @c_LabelName = '010'   THEN @c_LabelValue ELSE @c_rptfax   END   
          
      FETCH NEXT FROM CUR_LBL INTO @c_LabelName, @c_LabelValue    
   END  
   CLOSE CUR_LBL  
   DEALLOCATE CUR_LBL  
  
  
   INSERT INTO #TMP_LoadOH09 (storerkey, loadkey, Orderkey,ExtOrdKey)  
      SELECT @c_storerkey, OH.LoadKey,oh.OrderKey,oh.ExternOrderKey  
      FROM ORDERS OH (NOLOCK)  
      WHERE LoadKey = @c_loadkey  
     
   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT DISTINCT Storerkey,loadkey,Orderkey,ExtOrdKey  
      FROM   #TMP_LoadOH09     
      WHERE loadkey = @c_loadkey    
    
   OPEN CUR_RESULT     
       
   FETCH NEXT FROM CUR_RESULT INTO @c_getstorerkey,@c_getLoadkey,@c_getOrderkey,@c_getExtOrderkey      
       
   WHILE @@FETCH_STATUS <> -1    
   BEGIN      
      
  INSERT INTO #TMP_SMBLOAD09  
  (  
   -- rowid -- this column value is auto-generated  
   Orderkey,  
   loadkey,  
   ST_Company,  
   SKU,  
   SDESCR,  
   PUOM01,  
   PUOM03,  
   C_Address1,  
   Lottable04,  
   PQty,  
   CaseCnt,  
   ExtOrdKey,  
   ORDDate,  
   consigneekey,  
   C_Address2,  
   C_Address3,  
   C_Contact1,  
   C_Contact2,  
   C_Phone1,  
   C_Phone2,  
   BillToKey,  
   ST_notes1,  
   BuyerPO,  
   Lottable02,  
   Facility,  
   C_Address4,  
   OHNotes,  
   DeliveryDate,  
   STDNETWGT,  
   StdCube,  
   rptremarks, rptcompany1, rptcompany2, rptcompany3, rptcompany4, rptcompany5,  
   rptcompany6, rptadd1, rptadd2, rpttel, rptfax  
  )  
    SELECT orders.orderkey,orders.loadkey,storer.company,  
           orderdetail.Sku,  
           CASE WHEN ISNULL(sku.busr1,'') <> '' THEN (LTRIM(RTRIM(ISNULL(Sku.busr1,''))) + LTRIM(RTRIM(ISNULL(Sku.busr1,''))))  
           ELSE CASE WHEN ISNULL(orders.userdefine01,'') = '' THEN RTRIM(sku.DESCR) ELSE (RTRIM(sku.DESCR)  + ISNULL(orders.userdefine01,'')) END END,  
           CASE WHEN PACK.PackUOM1 = 'CA' THEN N'箱' ELSE PACK.PackUOM1 END,   
           CASE WHEN PACK.PackUOM3 = 'BOT' THEN N'瓶' ELSE PACK.PackUOM3 END,   
           ISNULL(RTRIM(orders.c_Address1), ''),CONVERT(NVARCHAR(10),lot.lottable04,121) AS lottable04,  
           Sum(pickdetail.qty),pack.CaseCnt,orders.ExternOrderKey,  
           orders.OrderDate,orders.ConsigneeKey,ISNULL(RTRIM(orders.c_Address2), '') ,  
           ISNULL(RTRIM(orders.c_Address3), '') ,  
           CASE WHEN ISNULL(RTRIM(orders.c_Contact1), '') <> '' THEN  ISNULL(RTRIM(orders.c_Contact1), '') ELSE ISNULL(storer.contact1,'') END,  
           CASE WHEN ISNULL(RTRIM(orders.c_Contact2), '') <> '' THEN  ISNULL(RTRIM(orders.c_Contact2), '') ELSE ISNULL(storer.contact2,'') END,  
           CASE WHEN ISNULL(RTRIM(orders.C_Phone1), '') <> '' THEN  ISNULL(RTRIM(orders.C_Phone1), '') ELSE ISNULL(storer.Phone1,'') END,  
           CASE WHEN ISNULL(RTRIM(orders.C_Phone2), '') <> '' THEN  ISNULL(RTRIM(orders.C_Phone2), '') ELSE ISNULL(storer.Phone2,'') END,  
           ISNULL(RTRIM(orders.billtokey), ''),  
           ISNULL(RTRIM(storer.notes1), ''),ISNULL(RTRIM(orders.buyerpo), ''),ISNULL(RTRIM(lot.lottable02),'') AS lottable02,  
           orders.Facility,ISNULL(RTRIM(orders.c_Address4), ''),ISNULL(RTRIM(orders.notes), '')  
           ,orders.DeliveryDate,sku.STDNETWGT,sku.STDCUBE,  
           ISNULL(c1.Notes,''),  
           --CASE WHEN ISNULL(c2.code2,'') = '001' THEN ISNULL(c2.Notes,'') ELSE '' END,  
           --CASE WHEN ISNULL(c2.code2,'') = '002' THEN ISNULL(c2.Notes,'') ELSE '' END,  
           --CASE WHEN ISNULL(c2.code2,'') = '003' THEN ISNULL(c2.Notes,'') ELSE '' END,  
           --CASE WHEN ISNULL(c2.code2,'') = '004' THEN ISNULL(c2.Notes,'') ELSE '' END,  
           --CASE WHEN ISNULL(c2.code2,'') = '005' THEN ISNULL(c2.Notes,'') ELSE '' END,  
           --CASE WHEN ISNULL(c2.code2,'') = '006' THEN ISNULL(c2.Notes,'') ELSE '' END,     
           --CASE WHEN ISNULL(c2.code2,'') = '007' THEN ISNULL(c2.Notes,'') ELSE '' END,  
           --CASE WHEN ISNULL(c2.code2,'') = '008' THEN ISNULL(c2.Notes,'') ELSE '' END,  
           --CASE WHEN ISNULL(c2.code2,'') = '009' THEN ISNULL(c2.Notes,'') ELSE '' END,  
           --CASE WHEN ISNULL(c2.code2,'') = '010' THEN ISNULL(c2.Notes,'') ELSE '' END   
           @c_rptcompany1,@c_rptcompany2,@c_rptcompany3,@c_rptcompany4,@c_rptcompany5,@c_rptcompany6,  
           @c_rptadd1,@c_rptadd2,@c_rpttel,@c_rptfax  
  FROM Orders orders  WITH (nolock)  
      LEFT JOIN orderdetail orderdetail  WITH  (nolock) on orderdetail.orderkey = orders.orderkey   
      LEFT JOIN storer storer  WITH (nolock) on orders.ConsigneeKey = storer.storerkey   
      JOIN sku sku WITH (nolock) on orderdetail.storerkey=sku.storerkey and orderdetail.sku = sku.sku   
      JOIN pack pack  WITH (nolock) on pack.packkey = sku.packkey   
      LEFT JOIN PickDetail pickdetail  WITH  (nolock) on pickdetail.OrderKey=orderdetail.OrderKey and pickdetail.OrderLineNumber=orderdetail.OrderLineNumber  
      LEFT JOIN LotAttribute lot  WITH (nolock) on pickdetail.Lot=lot.Lot  
      LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON c1.LISTNAME ='REMYCOM' AND c1.storerkey = orders.StorerKey AND c1.Code = orders.Facility  
     -- LEFT JOIN CODELKUP C2 WITH (NOLOCK) ON c2.LISTNAME ='REMYCOM1' AND c2.storerkey = orders.StorerKey AND c2.Code = orders.Facility  
   WHERE orders.StorerKey = @c_getstorerkey  
   AND orders.LoadKey = @c_getLoadkey  
   AND orders.Orderkey = @c_getOrderkey  
   GROUP BY  orders.orderkey,orders.loadkey,storer.company,  
         orderdetail.Sku,  
         CASE WHEN ISNULL(sku.busr1,'') <> '' THEN (LTRIM(RTRIM(ISNULL(Sku.busr1,''))) + LTRIM(RTRIM(ISNULL(Sku.busr1,''))))  
         ELSE CASE WHEN ISNULL(orders.userdefine01,'') = '' THEN RTRIM(sku.DESCR) ELSE (RTRIM(sku.DESCR)  + ISNULL(orders.userdefine01,'')) END END,  
         CASE WHEN PACK.PackUOM1 = 'CA' THEN N'箱' ELSE PACK.PackUOM1 END,   
         CASE WHEN PACK.PackUOM3 = 'BOT' THEN N'瓶' ELSE PACK.PackUOM3 END,   
         ISNULL(RTRIM(orders.c_Address1), ''),CONVERT(NVARCHAR(10),lot.lottable04,121) ,  
         pack.CaseCnt,orders.ExternOrderKey,  
         orders.OrderDate,orders.ConsigneeKey,ISNULL(RTRIM(orders.c_Address2), '') ,  
         ISNULL(RTRIM(orders.c_Address3), '') ,  
         CASE WHEN  ISNULL(RTRIM(orders.c_Contact1), '') <> '' THEN  ISNULL(RTRIM(orders.c_Contact1), '') ELSE ISNULL(storer.contact1,'') END,  
         CASE WHEN  ISNULL(RTRIM(orders.c_Contact2), '') <> '' THEN  ISNULL(RTRIM(orders.c_Contact2), '') ELSE ISNULL(storer.contact2,'') END,  
         CASE WHEN ISNULL(RTRIM(orders.C_Phone1), '') <> '' THEN  ISNULL(RTRIM(orders.C_Phone1), '') ELSE ISNULL(storer.Phone1,'') END,  
         CASE WHEN ISNULL(RTRIM(orders.C_Phone2), '') <> '' THEN  ISNULL(RTRIM(orders.C_Phone2), '') ELSE ISNULL(storer.Phone2,'') END,  
         ISNULL(RTRIM(orders.billtokey), ''),  
         ISNULL(RTRIM(storer.notes1), ''),ISNULL(RTRIM(orders.buyerpo), ''),lot.lottable02,  
         orders.Facility,ISNULL(RTRIM(orders.c_Address4), ''),ISNULL(RTRIM(orders.notes), '')  
         ,orders.DeliveryDate,sku.STDNETWGT,sku.STDCUBE,  
          ISNULL(c1.Notes,'')  
         --CASE WHEN ISNULL(c2.code2,'') = '001' THEN ISNULL(c2.Notes,'') ELSE '' END,  
         --CASE WHEN ISNULL(c2.code2,'') = '002' THEN ISNULL(c2.Notes,'') ELSE '' END,  
         --CASE WHEN ISNULL(c2.code2,'') = '003' THEN ISNULL(c2.Notes,'') ELSE '' END,  
         --CASE WHEN ISNULL(c2.code2,'') = '004' THEN ISNULL(c2.Notes,'') ELSE '' END,  
         --CASE WHEN ISNULL(c2.code2,'') = '005' THEN ISNULL(c2.Notes,'') ELSE '' END,  
         --CASE WHEN ISNULL(c2.code2,'') = '006' THEN ISNULL(c2.Notes,'') ELSE '' END,     
         --CASE WHEN ISNULL(c2.code2,'') = '007' THEN ISNULL(c2.Notes,'') ELSE '' END,  
         --CASE WHEN ISNULL(c2.code2,'') = '008' THEN ISNULL(c2.Notes,'') ELSE '' END,  
         --CASE WHEN ISNULL(c2.code2,'') = '009' THEN ISNULL(c2.Notes,'') ELSE '' END,  
         --CASE WHEN ISNULL(c2.code2,'') = '010' THEN ISNULL(c2.Notes,'') ELSE '' END   
   ORDER BY orders.orderkey,orders.loadkey,orders.ExternOrderKey,orderdetail.Sku  
        
   FETCH NEXT FROM CUR_RESULT INTO @c_getstorerkey,@c_getLoadkey,@c_getOrderkey ,@c_getExtOrderkey   
   END     
       
   SELECT  
    ts.Orderkey,  
    ts.StdCube,  
    ts.STDNETWGT,  
    ts.ST_Company,  
    ts.C_Address1,  
    ts.C_Contact1,  
    ts.C_Contact2,  
    ts.C_Phone1,  
    ts.C_Phone2,  
    ts.BillToKey,  
    ts.ST_notes1,  
    ts.BuyerPO,  
    ts.Lottable02,  
    ts.PUOM01,  
    ts.Facility,  
    ts.PUOM03,  
    ts.loadkey,  
    ts.Lottable04,  
    ts.SKU,  
    ts.ExtOrdKey,  
    ts.ORDDate,  
    ts.PQty,  
    ts.consigneekey,   
    ts.SDESCR,  
    ts.C_Address2,  
    ts.C_Address3,  
    ts.C_Address4,  
    ts.OHNotes,  
    ts.DeliveryDate,  
    ts.rptremarks, ts.rptcompany1, ts.CaseCnt,  
    ts.rptcompany2, ts.rptcompany3,  
    ts.rptcompany4, ts.rptcompany5, ts.rptcompany6, ts.rptadd1,  
    ts.rptadd2, ts.rpttel, ts.rptfax  
   FROM  
    #TMP_SMBLOAD09 AS ts  
    WHERE loadkey = @c_loadkey  
    ORDER BY ts.loadkey,ts.Orderkey,ts.ExtOrdKey,ts.SKU  
      
    QUIT_SP:  
          
END  

GO