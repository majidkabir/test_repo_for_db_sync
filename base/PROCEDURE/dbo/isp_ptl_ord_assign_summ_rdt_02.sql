SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_ptl_ord_assign_summ_rdt_02                          */
/* Creation Date: 06-JAN-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by: mingle(copy from isp_ptl_ord_assign_summ_rdt)            */
/*                                                                      */
/* Purpose: WMS-17115 PH_Young Living - Order Assign Summary Report     */
/*        :                                                             */
/* Called By: r_dw_ptl_ord_assign_summ_rdt_02                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 05-Jul-2021  Mingle    1.1 WMS-17115 - Add new mappings(ML01)        */
/* 25-Nov-2022  BeeTin    1.2 JSM-112611- Ext temp table column length  */  
/*                            to NVARCHAR(20) istead of NVARCHAR(10)    */
/************************************************************************/
CREATE PROC [dbo].[isp_ptl_ord_assign_summ_rdt_02]
           @c_waveKey   NVARCHAR(20)

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

 DECLARE                     
      @c_SQL             NVARCHAR(4000),        
      @c_SQLSORT         NVARCHAR(4000),        
      @c_SQLJOIN         NVARCHAR(4000),
      @c_condition1      NVARCHAR(150) ,
      @c_condition2      NVARCHAR(150),
      @c_SQLGroup        NVARCHAR(4000),
      @c_SQLOrdBy        NVARCHAR(150),
      @c_SQLinsert       NVARCHAR(4000) ,  
      @c_SQLSelect       NVARCHAR(4000),   
      @c_ExecStatements   NVARCHAR(4000),    
      @c_ExecArguments    NVARCHAR(4000),
      @c_chkpickzone      NVARCHAR(5),
      @c_UDF03           NVARCHAR(500)    --ML01


   IF ISNULL(@c_waveKey,'') = ''
   BEGIN
      GOTO QUIT_SP
   END

   SET @n_StartTCnt = @@TRANCOUNT

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END
  
    SET @c_SQL = ''    
    SET @c_SQLJOIN = ''        
    SET @c_condition1 = ''
    SET @c_condition2= ''
    SET @c_SQLOrdBy = ''
    SET @c_SQLGroup = ''
    SET @c_ExecStatements = ''
    SET @c_ExecArguments = ''
    SET @c_SQLinsert = ''
    SET @c_SQLSelect = ''

     CREATE TABLE #TMP_PTORDSUMMRDT
      (  RowID          INT IDENTITY (1,1) NOT NULL 
      ,  Orderkey       NVARCHAR(20)   NULL  DEFAULT('')
      ,  Wavekey        NVARCHAR(10)   NULL  DEFAULT('')
      ,  loadkey        NVARCHAR(20)   NULL  DEFAULT('')
      ,  PQty           INT            NULL  DEFAULT(0)
      ,  PickZone       NVARCHAR(20)   NULL  DEFAULT('')
      ,  OHDELDate      NVARCHAR(10)   NULL  DEFAULT('')
      ,  ExtOrdkey      NVARCHAR(50)   NULL  DEFAULT('')
      ,  courier        NVARCHAR(50)   NULL  DEFAULT('')   
      ,  courier2       NVARCHAR(50)   NULL  DEFAULT('') 
      ,  salesman       NVARCHAR(30)   NULL  DEFAULT('')    --ML01
      ,  storerkey      NVARCHAR(10)   NULL  DEFAULT('')    --ML01
      ,  shipperkey     NVARCHAR(20)   NULL  DEFAULT('')    --ML01 --(JSM-112611)  
     )

   CREATE TABLE #TMP_UDF03    --ML01
      ( Shipperkey      NVARCHAR(50)   NULL  DEFAULT(''),
        Storerkey       NVARCHAR(50)   NULL  DEFAULT('')
      )
  
   CREATE TABLE #TMP_PTORDBYSGRP
      (  RowID          INT IDENTITY (1,1) NOT NULL 
      ,  Orderkey       NVARCHAR(20)   NULL  DEFAULT('')
      ,  Wavekey        NVARCHAR(10)   NULL  DEFAULT('')
      ,  loadkey        NVARCHAR(20)   NULL  DEFAULT('')
      ,  SKUGRP         NVARCHAR(50)   NULL  DEFAULT('')
      )

   --START(ML01)
   INSERT INTO #TMP_UDF03(shipperkey,storerkey)    
   SELECT DISTINCT oh.shipperkey,oh.storerkey
   FROM WAVEDETAIL WD WITH (NOLOCK)
   JOIN ORDERS OH WITH (NOLOCK) ON OH.Orderkey = WD.Orderkey
   WHERE WD.WaveKey = @c_wavekey

   --SELECT @c_UDF03 = @c_UDF03 + CAST(STUFF((SELECT DISTINCT ',' + RTRIM(UDF03) FROM CODELKUP(NOLOCK) WHERE CODELKUP.listname ='SHIPMETHOD' AND CODELKUP.storerkey = #TMP_UDF03.Storerkey AND CODELKUP.code = #TMP_UDF03.ShipperKey
   --                  ORDER BY 1 FOR XML PATH('')),1,1,'' ) AS NVARCHAR(255)) 
   SELECT @c_UDF03 = CASE WHEN ISNULL(@c_UDF03,'') = '' THEN LTRIM(RTRIM(ISNULL(CODELKUP.UDF03,''))) ELSE ISNULL(@c_UDF03,'') + ',' + LTRIM(RTRIM(ISNULL(CODELKUP.UDF03,''))) END
   FROM #TMP_UDF03
   JOIN CODELKUP WITH (NOLOCK) ON CODELKUP.listname ='SHIPMETHOD' AND CODELKUP.storerkey = #TMP_UDF03.Storerkey AND CODELKUP.code = #TMP_UDF03.ShipperKey
   --END(ML01)
   


   INSERT INTO #TMP_PTORDBYSGRP(orderkey,wavekey,loadkey,SKUGRP)
    SELECT DISTINCT oh.orderkey,WV.wavekey as Wavekey,oh.loadkey,c.udf01 as SKUGRP
      FROM WAVE WV WITH (NOLOCK)
      JOIN WAVEDETAIL WD WITH (NOLOCK) ON WD.wavekey = WV.wavekey
      JOIN ORDERS OH WITH (NOLOCK) ON OH.Orderkey = WD.Orderkey
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.Orderkey = OH.Orderkey
      JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.Orderkey = OD.Orderkey AND PD.SKU = OD.SKU
                                AND PD.OrderLineNumber = OD.OrderLineNumber
      JOIN SKU S WITH (NOLOCK) ON S.Storerkey = PD.Storerkey AND S.sku=PD.sku
      LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname ='skugroup' AND C.storerkey = OH.Storerkey AND C.code = s.skugroup
      WHERE WV.Wavekey=@c_wavekey

      INSERT INTO #TMP_PTORDSUMMRDT(Orderkey,Wavekey,Loadkey,Pqty,Pickzone,OHDELDATE,ExtOrdkey,courier,salesman,storerkey,shipperkey)    --ML01     
      SELECT oh.orderkey,WV.wavekey as Wavekey,oh.loadkey,PD.qty,
             case when c.short='Y' THEN L.pickzone else '' END as pickzone,
             CONVERT(NVARCHAR(10),OH.deliverydate,101),oh.externorderkey,ISNULL(C1.code2,''),OH.Salesman,OH.Storerkey,OH.Shipperkey    --ML01                
      FROM WAVE WV WITH (NOLOCK)
      JOIN WAVEDETAIL WD WITH (NOLOCK) ON WD.wavekey = WV.wavekey
      JOIN ORDERS OH WITH (NOLOCK) ON OH.Orderkey = WD.Orderkey
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.Orderkey = OH.Orderkey
      JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.Orderkey = OD.Orderkey AND PD.SKU = OD.SKU
                                AND PD.OrderLineNumber = OD.OrderLineNumber
      JOIN LOC L WITH (NOLOCK) ON L.loc = PD.LOC
      LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'ordertype' AND C.code=OH.type 
                                AND C.storerkey = OH.Storerkey
      LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.listname = 'courierlbl' AND C1.code=OH.salesman 
                                AND C1.storerkey = OH.Storerkey
      LEFT JOIN CODELKUP C2 WITH (NOLOCK) ON C2.listname = 'shipmethod' AND C2.code=OH.shipperkey 
                                AND C2.storerkey = OH.Storerkey    --ML01
      WHERE WV.Wavekey=@c_wavekey

      SELECT Orderkey as Orderkey,
             Wavekey as Wavekey,
             Loadkey as loadkey,
             sum(Pqty) as PQTY,
             Pickzone as PickZone,
             OHDELDATE as OHDELDATE,
             ExtOrdkey as ExtOrdkey,
             Courier AS Courier,
             --Courier2 AS Courier2,
             @c_UDF03,    --ML01
             --CAST(STUFF((SELECT DISTINCT ',' + RTRIM(UDF03) FROM CODELKUP(NOLOCK) WHERE CODELKUP.listname ='SHIPMETHOD' AND CODELKUP.storerkey = #TMP_UDF03.Storerkey AND CODELKUP.code = #TMP_UDF03.ShipperKey
             --ORDER BY 1 FOR XML PATH('')),1,1,'' ) AS NVARCHAR(255)) AS Courier2,
             shipperkey AS shipperkey,    --ML01
             salesman AS salesman              
             ,CAST(STUFF((SELECT ',' + RTRIM(a.skugrp) FROM #TMP_PTORDBYSGRP a 
                          where a.orderkey = #TMP_PTORDSUMMRDT.orderkey and a.wavekey=#TMP_PTORDSUMMRDT.wavekey 
               ORDER BY a.wavekey, a.orderkey,a.skugrp FOR XML PATH('')),1,1,'' ) AS NVARCHAR(250)) AS SKUGRP
      FROM #TMP_PTORDSUMMRDT
      WHERE Wavekey = @c_wavekey
      GROUP BY Orderkey,Wavekey,Loadkey,Pickzone,OHDELDATE,ExtOrdkey,Courier,courier2,salesman,storerkey,shipperkey    --ML01      
      ORDER BY wavekey,orderkey

     DROP TABLE #TMP_PTORDSUMMRDT
     DROP TABLE #TMP_PTORDBYSGRP
   
 QUIT_SP:



 WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
       
END -- procedure

GO