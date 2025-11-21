SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_ptl_ord_assign_summ_rdt                             */
/* Creation Date: 06-JAN-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-15950 - [PH] - Adidas Ecom - Order Summary Report       */
/*        :                                                             */
/* Called By: r_dw_ptl_ord_assign_summ_rdt                              */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 01-MAR-2021  CSCHONG   1.1  WMS-15950 Add new field (CS01)           */
/************************************************************************/
CREATE PROC [dbo].[isp_ptl_ord_assign_summ_rdt]
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
      @c_chkpickzone      NVARCHAR(5)



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
      ,  courier        NVARCHAR(50)   NULL  DEFAULT('')             --CS01
     )
  /*CS01 START*/
   CREATE TABLE #TMP_PTORDBYSGRP
      (  RowID          INT IDENTITY (1,1) NOT NULL 
      ,  Orderkey       NVARCHAR(20)   NULL  DEFAULT('')
      ,  Wavekey        NVARCHAR(10)   NULL  DEFAULT('')
      ,  loadkey        NVARCHAR(20)   NULL  DEFAULT('')
      ,  SKUGRP         NVARCHAR(50)   NULL  DEFAULT('')
      )



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
  /*CS01 END*/
      INSERT INTO #TMP_PTORDSUMMRDT(Orderkey,Wavekey,Loadkey,Pqty,Pickzone,OHDELDATE,ExtOrdkey,courier)     --CS01
      SELECT oh.orderkey,WV.wavekey as Wavekey,oh.loadkey,PD.qty,
             case when c.short='Y' THEN L.pickzone else '' END as pickzone,
             CONVERT(NVARCHAR(10),OH.deliverydate,101),oh.externorderkey,ISNULL(C1.code2,'')                --CS01
      FROM WAVE WV WITH (NOLOCK)
      JOIN WAVEDETAIL WD WITH (NOLOCK) ON WD.wavekey = WV.wavekey
      JOIN ORDERS OH WITH (NOLOCK) ON OH.Orderkey = WD.Orderkey
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.Orderkey = OH.Orderkey
      JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.Orderkey = OD.Orderkey AND PD.SKU = OD.SKU
                                AND PD.OrderLineNumber = OD.OrderLineNumber
      JOIN LOC L WITH (NOLOCK) ON L.loc = PD.LOC
      LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'ordertype' AND C.code=OH.type 
                                AND C.storerkey = OH.Storerkey
      --CS01 START
      LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.listname = 'courierlbl' AND C1.code=OH.salesman 
                                AND C1.storerkey = OH.Storerkey
      --CS01 END
      WHERE WV.Wavekey=@c_wavekey

      SELECT Orderkey as Orderkey,
             Wavekey as Wavekey,
             Loadkey as loadkey,
             sum(Pqty) as PQTY,
             Pickzone as PickZone,
             OHDELDATE as OHDELDATE,
             ExtOrdkey as ExtOrdkey,
             Courier AS Courier              --CS01
             ,CAST(STUFF((SELECT ',' + RTRIM(a.skugrp) FROM #TMP_PTORDBYSGRP a 
                          where a.orderkey = #TMP_PTORDSUMMRDT.orderkey and a.wavekey=#TMP_PTORDSUMMRDT.wavekey 
               ORDER BY a.wavekey, a.orderkey,a.skugrp FOR XML PATH('')),1,1,'' ) AS NVARCHAR(250)) AS SKUGRP
      FROM #TMP_PTORDSUMMRDT
      WHERE Wavekey = @c_wavekey
      GROUP BY Orderkey,Wavekey,Loadkey,Pickzone,OHDELDATE,ExtOrdkey,Courier        --CS01
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