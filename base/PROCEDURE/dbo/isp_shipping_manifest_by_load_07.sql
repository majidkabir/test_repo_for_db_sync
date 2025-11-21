SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_shipping_manifest_by_load_07                    */
/* Creation Date: 2018-05-03                                             */
/* Copyright: IDS                                                        */
/* Written by:                                                           */
/*                                                                       */
/* Purpose: WMS-4831 -CN WMS Profex POD                                  */
/*                                                                       */
/* Called By: r_shipping_manifest_by_load_07                             */
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
CREATE PROC [dbo].[isp_shipping_manifest_by_load_07] 
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
          
  CREATE TABLE #TMP_LoadOH07 (
          rowid           int identity(1,1),
          storerkey       NVARCHAR(20) NULL,
          loadkey         NVARCHAR(50) NULL,
          Orderkey        NVARCHAR(10) NULL)           
   
   
   CREATE TABLE #TMP_SMBLOAD07 (
          rowid           int identity(1,1),
          Orderkey        NVARCHAR(20)  NULL,
          loadkey         NVARCHAR(50)  NULL,
          mbolkey         NVARCHAR(10)  NULL,
          Externorderkey  NVARCHAR(30)  NULL,
          MBEditdate      NVARCHAR(10)  NULL,
          C_Contact1      NVARCHAR(45)  NULL,
          C_Address1      NVARCHAR(45)  NULL,
          C_Company       NVARCHAR(45)  NULL,
          C_phone1        NVARCHAR(45)  NULL,
          C_phone2        NVARCHAR(45)  NULL,
          SKU             NVARCHAR(20)  NULL,
          SDESCR          NVARCHAR(150) NULL,
          OHDeliverydate  NVARCHAR(10)  NULL,
          OHAdddate       NVARCHAR(10)  NULL,
          OHOrderDate     NVARCHAR(10)  NULL,
          Lottable01      NVARCHAR(20)  NULL,
          Lottable02      NVARCHAR(20)  NULL,
          Lottable04      NVARCHAR(10)  NULL,
          Lottable06      NVARCHAR(30)  NULL,
          Altsku          NVARCHAR(20)  NULL,
          OHNotes         NVARCHAR(250) NULL,
          SNotes1         NVARCHAR(250) NULL,
          SNotes2         NVARCHAR(250) NULL,
          PQty            INT NULL,
          ttlCtn          INT NULL,
          CaseCnt         FLOAT NULL,
          StdCube         FLOAT NULL,
          StdNWgt         FLOAT NULL,
          StdGrossWgt     FLOAT NULL,
          recgrp          INT)           
   
   
   SET @n_NoOfLine = 6
   
   SELECT TOP 1 @c_storerkey = OH.Storerkey
   FROM ORDERS OH (NOLOCK)
   WHERE Loadkey = @c_loadkey
   
   
    INSERT INTO #TMP_LoadOH07 (storerkey, loadkey, Orderkey)
    SELECT @c_storerkey, OH.LoadKey,oh.OrderKey
    FROM ORDERS OH (NOLOCK)
    WHERE LoadKey = @c_loadkey
      
    DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT Storerkey,loadkey,Orderkey  
   FROM   #TMP_LoadOH07    
   WHERE loadkey = @c_loadkey  
  
   OPEN CUR_RESULT   
     
   FETCH NEXT FROM CUR_RESULT INTO @c_getstorerkey,@c_getLoadkey,@c_getOrderkey    
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN    
      
      INSERT INTO #TMP_SMBLOAD07
      (
         -- rowid -- this column value is auto-generated
         Orderkey,
         loadkey,
         mbolkey,
         Externorderkey,
         MBEditdate,
         C_Contact1,
         C_Address1,
         C_Company,
         C_phone1,
         C_phone2,
         SKU,
         SDESCR,
         OHDeliverydate,
         OHAdddate,
         OHOrderDate,
         Lottable01,
         Lottable02,
         Lottable04,
         Lottable06,
         Altsku,
         OHNotes,
         SNotes1,
         SNotes2,
         PQty,
         ttlCtn,
         CaseCnt,
         StdCube,
         StdNWgt,
         StdGrossWgt,
         recgrp
      )
      
      SELECT orders.orderkey,orders.loadkey,orders.mbolkey,orders.externorderkey,CONVERT(NVARCHAR(10),mbol.editdate,111) AS MBEditdate,
            orders.C_contact1,orders.C_address1 , orders.C_company,orders.C_phone1,orders.C_phone2,
            orderdetail.Sku,sku.DESCR,CONVERT(NVARCHAR(10),orders.deliverydate,111) AS DelDate, 
            CONVERT(NVARCHAR(10),orders.adddate,111) AS ORDADDDate,CONVERT(NVARCHAR(10),orders.orderdate,111) AS ORDERDate,
            lot.lottable01,lot.lottable02,CONVERT(NVARCHAR(10),lot.lottable04,111) AS loattable04,lot.lottable06,SKU.ALTSKU,
            orders.NOTES,SKU.NOTES1,sku.Notes2,Sum(pickdetail.qty),
            ((sum(floor(pickdetail.qty/pack.casecnt)))+(packheader.TTLCNTS) - 1),pack.casecnt,sum(sku.stdcube*pickdetail.Qty),sum(sku.stdnetwgt*pickdetail.qty),
            sku.stdgrosswgt,
             (Row_Number() OVER (PARTITION BY orders.orderkey,orders.loadkey ORDER BY orderdetail.Sku Asc)-1)/@n_NoOfLine+1 AS recgrp
      FROM Orders orders  WITH (nolock)
      LEFT JOIN orderdetail orderdetail  WITH  (nolock) on orderdetail.orderkey = orders.orderkey 
      LEFT JOIN storer storer  WITH (nolock) on orders.ConsigneeKey = storer.storerkey 
      LEFT JOIN sku sku WITH (nolock) on orderdetail.storerkey=sku.storerkey and orderdetail.sku = sku.sku 
      LEFT JOIN pack pack  WITH (nolock) on pack.packkey = sku.packkey 
      LEFT JOIN mbol mbol  WITH (nolock) on orders.mbolkey=mbol.mbolkey
      LEFT JOIN PickDetail pickdetail  WITH  (nolock) on pickdetail.OrderKey=orderdetail.OrderKey and pickdetail.OrderLineNumber=orderdetail.OrderLineNumber
      LEFT JOIN LotAttribute lot  WITH (nolock) on pickdetail.Lot=lot.Lot
     LEFT JOIN  packheader packheader  WITH (nolock) on orders.orderkey=packheader.orderkey
       WHERE orders.StorerKey = @c_getstorerkey
         AND orders.LoadKey = @c_getLoadkey
         AND orders.Orderkey = @c_getOrderkey
       GROUP BY  orders.orderkey,orders.loadkey,orders.mbolkey,orders.externorderkey,CONVERT(NVARCHAR(10),mbol.editdate,111),
            orders.C_contact1,orders.C_address1 , orders.C_company,orders.C_phone1,orders.C_phone2,
            orderdetail.Sku,sku.DESCR,CONVERT(NVARCHAR(10),orders.deliverydate,111), 
            CONVERT(NVARCHAR(10),orders.adddate,111),CONVERT(NVARCHAR(10),orders.orderdate,111) ,
            lot.lottable01,lot.lottable02,CONVERT(NVARCHAR(10),lot.lottable04,111),lot.lottable06,SKU.ALTSKU,
            orders.NOTES,SKU.NOTES1,sku.Notes2,pack.casecnt,
            sku.stdgrosswgt,packheader.TTLCNTS
       ORDER BY orders.orderkey,orders.loadkey,orderdetail.Sku

      
   FETCH NEXT FROM CUR_RESULT INTO @c_getstorerkey,@c_getLoadkey,@c_getOrderkey  
   END   
         
   SELECT
      ts.Orderkey,
      ts.loadkey,
      ts.mbolkey,
      ts.Externorderkey,
      ts.MBEditdate,
      ts.C_Contact1,
      ts.C_Address1,
      ts.C_Company,
      ts.C_phone1,
      ts.C_phone2,
      ts.SKU,
      ts.SDESCR,
      ts.OHDeliverydate,
      ts.OHAdddate,
      ts.OHOrderDate,
      ts.Lottable01,
      ts.Lottable02,
      ts.Lottable04,
      ts.Lottable06,
      ts.Altsku,
      ts.OHNotes,
      ts.SNotes1,
      ts.SNotes2,
      ts.PQty,
      ts.ttlCtn,
      ts.CaseCnt,
      ts.StdCube,
      ts.StdNWgt,
      ts.StdGrossWgt,
      ts.recgrp
   FROM
      #TMP_SMBLOAD07 AS ts
    WHERE loadkey = @c_loadkey
    ORDER BY loadkey,Orderkey,SKU
    
    QUIT_SP:
    
END


GO