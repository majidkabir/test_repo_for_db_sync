SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_shipping_manifest_by_load_13                    */
/* Creation Date: 2018-08-09                                             */
/* Copyright: IDS                                                        */
/* Written by:                                                           */
/*                                                                       */
/* Purpose:WMS-5151 CN WMS MHD POD                                       */
/*                                                                       */
/* Called By: r_shipping_manifest_by_load_13                             */
/*                                                                       */
/* PVCS Version: 1.1                                                     */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author  Ver   Purposes                                   */
/* 01-AUG-2019  CSCHONG 1.0   WMS-9952 revised field logic (CS01)        */
/* 16-AUG-2019  CSCHONG 1.1   WMS-9952 revised field logic (CS02)        */
/* 14-JAN-2021  CSCHONG 1.2   Fix wrong alias (CS03)                     */
/*************************************************************************/
CREATE PROC [dbo].[isp_shipping_manifest_by_load_13]
         (  @c_loadkey    NVARCHAR(10)
         )
         
         
         
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE   @c_storerkey      NVARCHAR(10)
          ,@n_NoOfLine       INT
          ,@c_getstorerkey   NVARCHAR(10)
          ,@c_getLoadkey     NVARCHAR(20)
          ,@c_getOrderkey    NVARCHAR(20)
          ,@c_getExtOrderkey NVARCHAR(20)
          ,@c_OHType         NVARCHAR(30)
          ,@c_Facility       NVARCHAR(50)
          ,@c_DelDateTitle   NVARCHAR(150)
          ,@c_CNametitle     NVARCHAR(150)
          ,@c_CContactTitle  NVARCHAR(150)
          ,@n_maxline        INT
          
  CREATE TABLE #TMP_LoadOH13(
          rowid           int identity(1,1),
          storerkey       NVARCHAR(20) NULL,
          loadkey         NVARCHAR(50) NULL,
          Orderkey        NVARCHAR(10) NULL,
          ExtOrdKey       NVARCHAR(10) NULL)           
    
   CREATE TABLE #TMP_SMBLOAD13 (
          rowid           int identity(1,1),
          Orderkey        NVARCHAR(20)  NULL,
          loadkey         NVARCHAR(50)  NULL,
          C_Company       NVARCHAR(45)  NULL,
          SKU             NVARCHAR(20)  NULL,
          SDESCR          NVARCHAR(150) NULL,
          Deliverydate    NVARCHAR(80)  NULL,
          PQty            INT,
          CaseCnt         FLOAT,
          ExtOrdKey       NVARCHAR(20) NULL,  
          consigneekey    NVARCHAR(45) NULL,
          C_Contact1      NVARCHAR(45) NULL,
          C_Phone1        NVARCHAR(45) NULL,
          CaseCnt2        INT,
          PCS             INT,
          STDNETWGT       FLOAT NULL,
          StdCube         FLOAT NULL,
          ST_Company      NVARCHAR(45) NULL,
          C_Address1      NVARCHAR(45) NULL,
          TTLCTN          INT,
          MBWGT           FLOAT,
          MBCUBE          FLOAT,
          Facility        NVARCHAR(50) NULL,
          Lottable01      NVARCHAR(20) NULL,
          Lottable02      NVARCHAR(20) NULL,
          C_State         NVARCHAR(45) NULL,
          C_CITY          NVARCHAR(45) NULL,
          C_Address2      NVARCHAR(45) NULL,
          C_Address3      NVARCHAR(45) NULL,
          C_Contact2      NVARCHAR(45) NULL,
          C_Phone2        NVARCHAR(45) NULL,
          ShipperKey      NVARCHAR(45) NULL,
          CarrierName     NVARCHAR(45) NULL,
          CarrierContact  NVARCHAR(90) NULL,
          F_Phone1        NVARCHAR(45) NULL,
          F_Phone2        NVARCHAR(45) NULL, 
          ST_Contact1     NVARCHAR(45) NULL,
          ST_Contact2     NVARCHAR(45) NULL,
          B_Phone1        NVARCHAR(45) NULL,
          OHUDF03         NVARCHAR(50) NULL,
          OHUDF04         NVARCHAR(50) NULL,
          OHNotes         NVARCHAR(120) NULL,
          OHNOtes2        NVARCHAR(120) NULL,
          OHEditDate      DATETIME ,
          RetailSKU       NVARCHAR(30) NULL,
          CNametitle      NVARCHAR(120) NULL,
          CContactTitle   NVARCHAR(120) NULL ,
          RecGrp          INT,
          C01             NVARCHAR(200)  NULL,
          C02             NVARCHAR(200)  NULL,
          C03             NVARCHAR(200)  NULL,
          C04             NVARCHAR(200)  NULL,
          C05             NVARCHAR(200)  NULL,
          C06             NVARCHAR(200)  NULL,
          C07             NVARCHAR(200)  NULL,
          C08             NVARCHAR(200)  NULL,
          C09             NVARCHAR(200)  NULL,
          C10             NVARCHAR(200)  NULL,
          C11             NVARCHAR(200)  NULL,
          C12             NVARCHAR(200)  NULL,
          C13             NVARCHAR(200)  NULL,
          C14             NVARCHAR(200)  NULL,
          C15             NVARCHAR(200)  NULL,
          C16             NVARCHAR(200)  NULL,
          C17             NVARCHAR(200)  NULL,
          C18             NVARCHAR(200)  NULL,
          C19             NVARCHAR(200)  NULL,
          C20             NVARCHAR(200)  NULL,
          C21             NVARCHAR(200)  NULL,
          C22             NVARCHAR(200)  NULL,
          C23             NVARCHAR(200)  NULL,
          C24             NVARCHAR(200)  NULL,
          C25             NVARCHAR(200)  NULL,
          C26             NVARCHAR(200)  NULL,
          C27             NVARCHAR(200)  NULL,
          C28             NVARCHAR(200)  NULL,
          C29             NVARCHAR(200)  NULL,
          C30             NVARCHAR(200)  NULL,
          C31             NVARCHAR(200)  NULL,
          C32             NVARCHAR(200)  NULL,
          C33             NVARCHAR(200)  NULL,
          C34             NVARCHAR(200)  NULL,
          C35             NVARCHAR(200)  NULL,
          C36             NVARCHAR(200)  NULL,
          C37             NVARCHAR(200)  NULL
          )       
   
   
  -- SET @n_NoOfLine = 6

  SET @c_OHType = ''
  SET @c_DelDateTitle = ''
  SET @c_CNametitle = ''
  SET @c_CContactTitle = ''
  SET @n_maxline = 11
  SET @c_storerkey = ''
   
    IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE Loadkey = @c_loadkey)
    BEGIN
          SELECT TOP 1 @c_storerkey = OH.Storerkey
                   ,@c_OHType = OH.[type]
         FROM ORDERS OH (NOLOCK)
         WHERE Loadkey = @c_loadkey 
    END
   ELSE IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE orderkey = @c_loadkey)
   BEGIN
          SELECT TOP 1 @c_storerkey = OH.Storerkey
                   ,@c_OHType = OH.[type]
         FROM ORDERS OH (NOLOCK)
         WHERE Orderkey = @c_loadkey 
    END


   SELECT @c_Facility = CASE WHEN @c_OHType = 'CNY' THEN C.UDF01 ELSE C.UDF02 END
   FROM CODELKUP C WITH (NOLOCK) 
   WHERE C.LISTNAME='MHDPODH' 
   AND C.Storerkey=@c_StorerKey AND C.Code='Facility2'

   SELECT @c_DelDateTitle = CASE WHEN @c_OHType = 'CNY' THEN C.UDF01 ELSE C.UDF02 END
   FROM CODELKUP C WITH (NOLOCK) 
   WHERE C.LISTNAME='MHDPODH' 
   AND C.Storerkey=@c_StorerKey AND C.Code='DeliveryDate'
   
   SELECT @c_CNametitle = CASE WHEN @c_OHType = 'CNY' THEN C.UDF01 ELSE C.UDF02 END
   FROM CODELKUP C WITH (NOLOCK) 
   WHERE C.LISTNAME='MHDPODH' 
   AND C.Storerkey=@c_StorerKey AND C.Code='CarrierName'

   SELECT @c_CContactTitle = CASE WHEN @c_OHType = 'CNY' THEN C.UDF01 ELSE C.UDF02 END
   FROM CODELKUP C WITH (NOLOCK) 
   WHERE C.LISTNAME='MHDPODH' 
   AND C.Storerkey=@c_StorerKey AND C.Code='CarrierContact'
   
   
   
    IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE Loadkey = @c_loadkey)
    BEGIN
       INSERT INTO #TMP_LoadOH13 (storerkey, loadkey, Orderkey,ExtOrdKey)
       SELECT @c_storerkey, OH.LoadKey,oh.OrderKey,oh.ExternOrderKey
        FROM ORDERS OH (NOLOCK)
        WHERE LoadKey = @c_loadkey 
    END
    ELSE IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE orderkey = @c_loadkey)
    BEGIN
       INSERT INTO #TMP_LoadOH13 (storerkey, loadkey, Orderkey,ExtOrdKey)
        SELECT @c_storerkey, OH.LoadKey,oh.OrderKey,oh.ExternOrderKey
        FROM ORDERS OH (NOLOCK)
        WHERE orderkey = @c_loadkey 

    END

      
   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT Storerkey,loadkey,Orderkey,ExtOrdKey
   FROM   #TMP_LoadOH13   
   --WHERE loadkey = @c_loadkey  OR Orderkey = @c_loadkey
  
   OPEN CUR_RESULT   
     
   FETCH NEXT FROM CUR_RESULT INTO @c_getstorerkey,@c_getLoadkey,@c_getOrderkey,@c_getExtOrderkey    
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN    
      
  INSERT INTO #TMP_SMBLOAD13
  (
   -- rowid -- this column value is auto-generated
          Orderkey,
          loadkey,
          C_Company,
          SKU,
          SDESCR,
          Deliverydate,
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
          ST_company,C_Address1,
          TTLCTN ,
          MBWGT  ,
          MBCUBE ,
          Facility ,
          Lottable01,
          Lottable02,
          C_State ,
          C_CITY  ,
          C_Address2,
          C_Address3,
          C_Contact2,
          C_Phone2,
          ShipperKey,
          CarrierName,
          CarrierContact,
          F_Phone1,
          F_Phone2, 
          ST_Contact1,
          ST_Contact2,
          B_Phone1,
          OHUDF03,
          OHUDF04,
          OHNotes,
          OHNOtes2,
          OHEditDate,
          RetailSKU,
          CNametitle,
          CContactTitle,
          RecGrp,
          C01,
          C02,
          C03,
          C04,
          C05,
          C06,
          C07,
          C08,
          C09,
          C10,
          C11,
          C12,
          C13,
          C14,
          C15,
          C16,
          C17,
          C18,
          C19,
          C20,
          C21,
          C22,
          C23,
          C24,
          C25,
          C26,
          C27,
          C28,
          C29,
          C30,
          C31,
          C32,
          C33,
          C34,
          C35,
          C36,
          C37
  )
      SELECT orders.orderkey,orders.loadkey,orders.c_company,
           orderdetail.Sku,
            RTRIM(sku.DESCR),
            @c_DelDateTitle + ' ' + CASE WHEN @c_OHType = 'CNY' THEN CONVERT(NVARCHAR(10),orders.Deliverydate,120) ELSE '' END AS Deliverydate,
            Sum(pickdetail.qty),
            pack.CaseCnt,
            orders.ExternOrderKey,orders.consigneekey,
             ISNULL(RTRIM(orders.c_Contact1), ''),
             ISNULL(RTRIM(orders.C_Phone1), '') ,
            Sum(pickdetail.qty)/NULLIF(CAST(pack.casecnt as int),0),
            Sum(pickdetail.qty)%NULLIF(CAST(pack.casecnt as int),0),
             cast(Sum(pickdetail.qty)*sku.StdGrossWgt as decimal(9,4)),
             Sum(pickdetail.qty) *sku.StdCube,
             storer.company,ISNULL(C_Address1,'') , 
             CASE WHEN MD.CtnCnt1 >0 THEN MD.CtnCnt1 ELSE MD.TotalCartons END,
             MD.[Weight],MD.[Cube],@c_Facility,'','',--lot.lottable01,lot.lottable02,   --CS02
             ISNULL(orders.c_state,''),ISNULL(orders.C_CITY,''),ISNULL(orders.C_Address2,''),
             ISNULL(orders.C_Address3,''), ISNULL(RTRIM(orders.c_Contact2), ''),
             ISNULL(RTRIM(orders.C_Phone2), '') ,orders.ShipperKey,
             CASE WHEN @c_OHType = 'CNY' THEN ISNULL(orders.UserDefine03,'') ELSE ST.company END,
             CASE WHEN @c_OHType = 'CNY' THEN ISNULL(orders.UserDefine04,'') ELSE ISNULL(ST.contact1,'') + ' ' + ISNULL(ST.contact2,'') END,
             ISNULL(ST.Phone1,''),ISNULL(ST.Phone2,''),ISNULL(storer.contact1,'') ,ISNULL(storer.contact2,'') ,
             ISNULL(ORDERS.B_Phone1, ''),ISNULL(orders.B_Contact2,''),ISNULL(ORDERS.B_Phone1,''),--ISNULL(orders.UserDefine03,''),ISNULL(orders.UserDefine04,'') ,   --CS01
             ISNULL(RTRIM(ORDERS.notes), ''), ISNULL(RTRIM(ORDERS.notes2), '') ,orders.editdate,sku.retailsku ,@c_CNametitle,@c_CContactTitle,
             Recgrp = Row_number() OVER (PARTITION BY orders.loadkey,orders.orderkey,orders.ExternOrderKey,orderdetail.Sku  ORDER BY orderdetail.sku),
             C01 = lbl.C01,
             C02 = lbl.C02,
             C03 = lbl.C03,
             C04 = lbl.C04,
             C05 = lbl.C05,
             C06 = lbl.C06,
             C07 = lbl.C07,
             C08 = lbl.C08,
             C09 = lbl.C09,
             C10 = lbl.C10,
             C11 = lbl.C11,
             C12 = lbl.C12,
             C13 = lbl.C13,
             C14 = lbl.C14,
             C15 = lbl.C15,
             C16 = lbl.C16,
             C17 = lbl.C17,
             C18 = lbl.C18,
             C19 = lbl.C19,
             C20 = lbl.C20,
             C21 = lbl.C21,
             C22 = lbl.C22,
             C23 = lbl.C23,
             C24 = lbl.C24,
             C25 = lbl.C25,
             C26 = lbl.C26,
             C27 = lbl.C27,
             C28 = lbl.C28,
             C29 = lbl.C29,
             C30 = lbl.C30,
             C31 = lbl.C31,
             C32 = lbl.C32,
             C33 = lbl.C33,
             C34 = lbl.C34,
             C35 = lbl.C35,
             C36 = lbl.C36,
             C37 = lbl.C37
      FROM Orders orders  WITH (nolock)
      JOIN MBOLDETAIL MD WITH (NOLOCK) ON MD.Orderkey = orders.orderkey
      JOIN orderdetail orderdetail  WITH  (nolock) on orderdetail.orderkey = orders.orderkey 
      JOIN storer storer  WITH (nolock) on orders.storerkey = storer.storerkey 
      JOIN sku sku WITH (nolock) on orderdetail.storerkey=sku.storerkey and orderdetail.sku = sku.sku 
      JOIN pack pack  WITH (nolock) on pack.packkey = sku.packkey 
      LEFT JOIN PickDetail pickdetail  WITH  (nolock) on pickdetail.OrderKey=orderdetail.OrderKey and pickdetail.OrderLineNumber=orderdetail.OrderLineNumber
      --LEFT JOIN LotAttribute lot  WITH (nolock) on pickdetail.Lot=lot.Lot    --CS02
      LEFT JOIN storer ST  WITH (nolock) on orders.ShipperKey = ST.storerkey   --CS03
      LEFT JOIN fnc_manifest_by_load13 (@c_getOrderkey) lbl ON (lbl.orderkey = orders.Orderkey)
       WHERE orders.StorerKey = @c_getstorerkey
       AND orders.LoadKey = @c_getLoadkey
       AND orders.Orderkey = @c_getOrderkey
       GROUP BY orders.orderkey,orders.loadkey,orders.c_company,
                orderdetail.Sku,
                RTRIM(sku.DESCR),
                CONVERT(NVARCHAR(10),orders.Deliverydate,120),
                pack.CaseCnt,
                orders.ExternOrderKey,orders.consigneekey,
                ISNULL(RTRIM(orders.c_Contact1), ''),
                ISNULL(RTRIM(orders.C_Phone1), '') ,
                storer.company,ISNULL(C_Address1,'') , 
                CASE WHEN MD.CtnCnt1 >0 THEN MD.CtnCnt1 ELSE MD.TotalCartons END,
                MD.[Weight],MD.[Cube],--lot.lottable01,lot.lottable02,          --CS02
                ISNULL(orders.c_state,''),ISNULL(orders.C_CITY,''),ISNULL(orders.C_Address2,''),
                ISNULL(orders.C_Address3,''), ISNULL(RTRIM(orders.c_Contact2), ''),
                ISNULL(RTRIM(orders.C_Phone2), '') ,orders.ShipperKey,
                CASE WHEN @c_OHType = 'CNY' THEN ISNULL(orders.UserDefine03,'') ELSE ST.company END,
                CASE WHEN @c_OHType = 'CNY' THEN ISNULL(orders.UserDefine04,'') ELSE ISNULL(ST.contact1,'') + ' ' + ISNULL(ST.contact2,'') END,
                ISNULL(ST.Phone1,''),ISNULL(ST.Phone2,''),ISNULL(storer.contact1,'') ,ISNULL(storer.contact2,'') ,
                ISNULL(ORDERS.B_Phone1, ''),ISNULL(orders.UserDefine03,''),ISNULL(orders.UserDefine04,'') , 
                ISNULL(RTRIM(ORDERS.notes), ''), ISNULL(RTRIM(ORDERS.notes2), '') ,orders.editdate,sku.retailsku,sku.StdGrossWgt,sku.StdCube,
                lbl.C01,
                lbl.C02,
                lbl.C03,
                lbl.C04,
                lbl.C05,
                lbl.C06,
                lbl.C07,
                lbl.C08,
                lbl.C09,
                lbl.C10,
                lbl.C11,
                lbl.C12,
                lbl.C13,
                lbl.C14,
                lbl.C15,
                lbl.C16,
                lbl.C17,
                lbl.C18,
                lbl.C19,
                lbl.C20,
                lbl.C21,
                lbl.C22,
                lbl.C23,
                lbl.C24,
                lbl.C25,
                lbl.C26,
                lbl.C27,
                lbl.C28,
                lbl.C29,
                lbl.C30,
                lbl.C31,
                lbl.C32,
                lbl.C33,
                lbl.C34,
                lbl.C35,
                lbl.C36,
                lbl.C37,
				ISNULL(orders.B_Contact2,'')       --CS01 
       ORDER BY orders.orderkey,orders.loadkey,orders.ExternOrderKey,orderdetail.Sku

      
   FETCH NEXT FROM CUR_RESULT INTO @c_getstorerkey,@c_getLoadkey,@c_getOrderkey ,@c_getExtOrderkey 
   END   
         
   SELECT
          Orderkey,
          STDNETWGT,
          StdCube,
          C_Contact1,
          C_Phone1,
          C_Company,
          loadkey,
          Deliverydate,
          SKU,
          ExtOrdKey, 
          PQty, 
          ST_company,
          consigneekey,
          CaseCnt2,
          PCS ,
          SDESCR,
          CaseCnt,
          C_Address1,
          TTLCTN ,
          MBWGT  ,
          MBCUBE ,
          Facility ,
          Lottable01,
          Lottable02,
          C_State ,
          C_CITY  ,
          C_Address2,
          C_Address3,
          C_Contact2,
          C_Phone2,
          ShipperKey,
          CarrierName,
          CarrierContact,
          F_Phone1,
          F_Phone2, 
          ST_Contact1,
          ST_Contact2,
          B_Phone1,
          OHUDF03,
          OHUDF04,
          OHNotes,
          OHNOtes2,
          OHEditDate,
          RetailSKU,
          CNametitle,
          CContactTitle,
          Recgrp,
          C01,
          C02,
          C03,
          C04,
          C05,
          C06,
          C07,
          C08,
          C09,
          C10,
          C11,
          C12,
          C13,
          C14,
          C15,
          C16,
          C17,
          C18,
          C19,
          C20,
          C21,
          C22,
          C23,
          C24,
          C25,
          C26,
          C27,
          C28,
          C29,
          C30,
          C31,
          C32,
          C33,
          C34,
          C35,
          C36, 
          C37 
   FROM
      #TMP_SMBLOAD13
  --  WHERE ts.loadkey = @c_loadkey
    ORDER BY loadkey,Orderkey,ExtOrdKey,SKU
    
    QUIT_SP:
    
END


GO