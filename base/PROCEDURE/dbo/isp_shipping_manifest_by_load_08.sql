SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_shipping_manifest_by_load_08                    */
/* Creation Date: 2018-05-03                                             */
/* Copyright: IDS                                                        */
/* Written by:                                                           */
/*                                                                       */
/* Purpose: WMS-4838 -CN KELLOGG'S POD                                   */
/*                                                                       */
/* Called By: r_shipping_manifest_by_load_08                             */
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
CREATE PROC [dbo].[isp_shipping_manifest_by_load_08] 
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
          ,@c_getExtOrderkey NVARCHAR(20)
          
  CREATE TABLE #TMP_LoadOH08 (
          rowid           int identity(1,1),
          storerkey       NVARCHAR(20) NULL,
          loadkey         NVARCHAR(50) NULL,
          Orderkey        NVARCHAR(10) NULL,
          ExtOrdKey       NVARCHAR(10) NULL)           
    
   CREATE TABLE #TMP_SMBLOAD08 (
          rowid           int identity(1,1),
          Orderkey        NVARCHAR(20)  NULL,
          loadkey         NVARCHAR(50)  NULL,
          ODUDF03         NVARCHAR(30)  NULL,
          SKU             NVARCHAR(20)  NULL,
          SDESCR          NVARCHAR(150) NULL,
          PUOM01          NVARCHAR(10)  NULL,
          PUOM03          NVARCHAR(10)  NULL,
          Lottable03      NVARCHAR(20)  NULL,
          Lottable04      NVARCHAR(10)  NULL,
          PQty            INT,
          CaseCnt         FLOAT,
          mbolkey         NVARCHAR(20) NULL,
          ExtOrdKey       NVARCHAR(10) NULL,
          ORDDate         DATETIME ,
          consigneekey    NVARCHAR(45) NULL,
          C_Company       NVARCHAR(45) NULL,
          CAddress        NVARCHAR(200) NULL,
          C_Contact1      NVARCHAR(45) NULL,
          C_Contact2      NVARCHAR(45) NULL,
          C_Phone1        NVARCHAR(45) NULL,
          C_Phone2        NVARCHAR(45) NULL,
          BillToKey       NVARCHAR(20) NULL,
          ST_notes1       NVARCHAR(150) NULL,
          BuyerPO         NVARCHAR(30) NULL,
          Lottable02      NVARCHAR(18) NULL,
          Facility        NVARCHAR(10) NULL,
          ST_long         NVARCHAR(50) NULL,
          ST_udf01        NVARCHAR(50) NULL,
          ST_udf02        NVARCHAR(50) NULL,
          ST_udf03        NVARCHAR(50) NULL,
          ST_udf04        NVARCHAR(50) NULL, 
          ST_udf05        NVARCHAR(50) NULL,
          ST_short        NVARCHAR(50) NULL,
          STDNETWGT       FLOAT NULL,
          StdCube         FLOAT NULL,
          SHNotes         NVARCHAR(120) NULL,
          QDNotes         NVARCHAR(120) NULL)           
   
   
  -- SET @n_NoOfLine = 6
   
   SELECT TOP 1 @c_storerkey = OH.Storerkey
   FROM ORDERS OH (NOLOCK)
   WHERE Loadkey = @c_loadkey
   
   
    INSERT INTO #TMP_LoadOH08 (storerkey, loadkey, Orderkey,ExtOrdKey)
    SELECT @c_storerkey, OH.LoadKey,oh.OrderKey,oh.ExternOrderKey
    FROM ORDERS OH (NOLOCK)
    WHERE LoadKey = @c_loadkey
   	
    DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT Storerkey,loadkey,Orderkey,ExtOrdKey
   FROM   #TMP_LoadOH08   
   WHERE loadkey = @c_loadkey  
  
   OPEN CUR_RESULT   
     
   FETCH NEXT FROM CUR_RESULT INTO @c_getstorerkey,@c_getLoadkey,@c_getOrderkey,@c_getExtOrderkey    
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN   	
   	
   INSERT INTO #TMP_SMBLOAD08
   (
   	-- rowid -- this column value is auto-generated
   	Orderkey,
   	loadkey,
   	ODUDF03,
   	SKU,
   	SDESCR,
   	PUOM01,
   	PUOM03,
   	Lottable03,
   	Lottable04,
   	PQty,
   	CaseCnt,
   	mbolkey,
   	ExtOrdKey,
   	ORDDate,
   	consigneekey,
   	C_Company,
   	CAddress,
   	C_Contact1,
   	C_Contact2,
   	C_Phone1,
   	C_Phone2,
   	BillToKey,
   	ST_notes1,
   	BuyerPO,
   	Lottable02,
   	Facility,ST_long, ST_udf01, ST_udf02, 
   	ST_udf03, ST_udf04, ST_udf05, ST_short,
   	STDNETWGT, StdCube,SHNotes, QDNotes
   )
   	SELECT orders.orderkey,orders.loadkey,orderdetail.UserDefine03,
   	     orderdetail.Sku,(LTRIM(RTRIM(Sku.busr6)) + sku.DESCR),
   	     CASE WHEN PACK.PackUOM1 = 'CA' THEN N'箱' ELSE PACK.PackUOM1 END, 
   	      CASE WHEN PACK.PackUOM3 = 'BOT' THEN N'瓶' ELSE PACK.PackUOM3 END, 
   	      lot.lottable03,CONVERT(NVARCHAR(10),lot.lottable04,111) AS loattable04,
   	      Sum(pickdetail.qty),pack.CaseCnt,orders.MBOLKey,orders.ExternOrderKey,
   	      orders.OrderDate,orders.ConsigneeKey,orders.C_Company,
   	      ( ISNULL(RTRIM(orders.c_Address1), '') +  ISNULL(RTRIM(orders.c_Address2), '') 
   	       +  ISNULL(RTRIM(orders.c_Address3), '') +  ISNULL(RTRIM(orders.c_Address4), '') ),
   	       ISNULL(RTRIM(orders.c_Contact1), ''),ISNULL(RTRIM(orders.c_Contact2), ''),ISNULL(RTRIM(orders.C_Phone1), ''),
   	       ISNULL(RTRIM(orders.C_Phone2), ''),ISNULL(RTRIM(orders.billtokey), ''),
   	       ISNULL(RTRIM(storer.notes1), ''),ISNULL(RTRIM(orders.buyerpo), ''),lot.lottable02,
   	       orders.Facility,ISNULL(C.Long,''),ISNULL(C.udf01,''),ISNULL(C.udf02,''),ISNULL(C.udf03,''),
   	       ISNULL(C.udf04,''),ISNULL(C.short,''),ISNULL(C.udf05,'')
   	       ,sku.STDNETWGT,sku.STDCUBE,ISNULL(c1.Notes,''),ISNULL(c2.Notes,'')
		FROM Orders orders  WITH (nolock)
      LEFT JOIN orderdetail orderdetail  WITH  (nolock) on orderdetail.orderkey = orders.orderkey 
      LEFT JOIN storer storer  WITH (nolock) on orders.ConsigneeKey = storer.storerkey 
      JOIN sku sku WITH (nolock) on orderdetail.storerkey=sku.storerkey and orderdetail.sku = sku.sku 
      JOIN pack pack  WITH (nolock) on pack.packkey = sku.packkey 
      LEFT JOIN PickDetail pickdetail  WITH  (nolock) on pickdetail.OrderKey=orderdetail.OrderKey and pickdetail.OrderLineNumber=orderdetail.OrderLineNumber
      LEFT JOIN LotAttribute lot  WITH (nolock) on pickdetail.Lot=lot.Lot
      LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.LISTNAME='kelloggpod' AND C.Code=storer.SUSR1 AND c.storerkey = orders.Storerkey
      LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.LISTNAME='kelloggpod' AND C1.Code = 'SH' AND c1.storerkey = orders.Storerkey
      LEFT JOIN CODELKUP C2 WITH (NOLOCK) ON C2.LISTNAME='kelloggpod' AND C2.Code = 'QD' AND c2.storerkey = orders.Storerkey
		 WHERE orders.StorerKey = @c_getstorerkey
			AND orders.LoadKey = @c_getLoadkey
			AND orders.Orderkey = @c_getOrderkey
		 GROUP BY  orders.orderkey,orders.loadkey,orderdetail.UserDefine03,
   	     orderdetail.Sku,(LTRIM(RTRIM(Sku.busr6)) + sku.DESCR),
   	     CASE WHEN PACK.PackUOM1 = 'CA' THEN N'箱' ELSE PACK.PackUOM1 END, 
   	      CASE WHEN PACK.PackUOM3 = 'BOT' THEN N'瓶' ELSE PACK.PackUOM3 END, 
   	      lot.lottable03,CONVERT(NVARCHAR(10),lot.lottable04,111),pack.CaseCnt,
   	      orders.MBOLKey,orders.ExternOrderKey,
   	      orders.OrderDate,orders.ConsigneeKey,orders.C_Company,
   	      ( ISNULL(RTRIM(orders.c_Address1), '') +  ISNULL(RTRIM(orders.c_Address2), '') 
   	       +  ISNULL(RTRIM(orders.c_Address3), '') +  ISNULL(RTRIM(orders.c_Address4), '') ),
   	       ISNULL(RTRIM(orders.c_Contact1), ''),ISNULL(RTRIM(orders.c_Contact2), ''),ISNULL(RTRIM(orders.C_Phone1), ''),
   	       ISNULL(RTRIM(orders.C_Phone2), ''),ISNULL(RTRIM(orders.billtokey), ''),
   	       ISNULL(RTRIM(storer.notes1), '') ,ISNULL(RTRIM(orders.buyerpo), ''),lot.lottable02,
   	       orders.Facility,ISNULL(C.Long,''),ISNULL(C.udf01,''),ISNULL(C.udf02,''),ISNULL(C.udf03,''),
   	       ISNULL(C.udf04,''),ISNULL(C.short,''),ISNULL(C.udf05,''),sku.STDNETWGT,sku.STDCUBE
   	       ,ISNULL(c1.Notes,''),ISNULL(c2.Notes,'')
		 ORDER BY orders.orderkey,orders.loadkey,orders.ExternOrderKey,orderdetail.Sku

   	
   FETCH NEXT FROM CUR_RESULT INTO @c_getstorerkey,@c_getLoadkey,@c_getOrderkey ,@c_getExtOrderkey 
   END   
   		
    SELECT
    	--ts.rowid,
    	ts.Orderkey,
    	ts.StdCube,
    	ts.STDNETWGT, 
    	ts.ODUDF03,
    	ts.CAddress,
    	ts.C_Contact1,
    	ts.C_Contact2,
    	ts.C_Phone1,
    	ts.C_Phone2,
    	ts.BillToKey,
    	ts.ST_notes1,
    	ts.BuyerPO,
    	ts.Lottable02,
    	ts.C_Company,
    	ts.PUOM01,
    	ts.Facility,
    	ts.PUOM03,
    	ts.Lottable03,
    	ts.loadkey,
    	ts.Lottable04,
    	ts.SKU,
    	ts.ExtOrdKey,
    	ts.ORDDate,
    	ts.PQty,
    	ts.mbolkey,
    	ts.consigneekey,
    	ts.SDESCR,
    	ts.ST_long, ts.ST_udf01, ts.ST_udf02, ts.ST_udf03, ts.ST_udf04,
    	ts.ST_udf05, ts.ST_short,
    	ts.CaseCnt,ts.SHNotes,ts.QDNotes
    FROM
    	#TMP_SMBLOAD08 AS ts
    WHERE loadkey = @c_loadkey
    ORDER BY ts.loadkey,ts.Orderkey,ts.ExtOrdKey,ts.SKU
    
    QUIT_SP:
    
END


GO