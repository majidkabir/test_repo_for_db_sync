SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_print_loadpicklist_composite                   */
/* Creation Date: 30-MAR-2022                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:WMS-19203 -[KR] SS_PickSlip_Data Window_CR                   */
/*        :                                                             */
/* Called By: r_dw_print_loadpicklist_composite                         */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/*30-MAR-2022  CSCHONG  1.0   Devops Scripts Combine                    */
/************************************************************************/
CREATE PROC [dbo].[isp_print_loadpicklist_composite]
         @c_loadkey        NVARCHAR(10)
        ,@c_type           NVARCHAR(5) = 'H'
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

         , @n_MaxCartonNo     INT
         , @n_NoOfLine        INT
         , @c_orderkey        NVARCHAR(20)
         , @n_ctnOrder        INT = 1
         , @n_SumOpenQty      INT = 0

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_NoOfLine = 10

    IF @c_type = 'H' GOTO TYPE_H
    IF @c_type = 'D' GOTO TYPE_D

   TYPE_H:

   SELECT @n_SumOpenQty = SUM(od.OpenQty)
   FROM ORDERS OH WITH (NOLOCK)
   JOIN orderdetail OD (NOLOCK) ON OD.OrderKey = OH.OrderKey
   WHERE OH.LoadKey= @c_loadkey


   SELECT @n_ctnOrder = COUNT(DISTINCT OH.Orderkey)
   FROM ORDERS OH WITH (NOLOCK)
   WHERE OH.LoadKey= @c_loadkey

   SELECT ROW_NUMBER() OVER (ORDER BY OH.loadkey,OH.OrderKey)  AS seqno
      , OH.OrderKey AS Orderkey
      ,CONVERT(NVARCHAR(10),GETDATE(),126) AS PrnDate
      ,OH.LoadKey
      ,@n_ctnOrder AS OrderCnt
      ,@n_SumOpenQty AS ttlqty
      ,'Stussy Packing List' AS RptTitle
   FROM ORDERS OH WITH (NOLOCK)
   WHERE OH.LoadKey=@c_loadkey
   ORDER BY OH.loadkey,OH.OrderKey


  GOTO QUIT;

   TYPE_D:

   CREATE TABLE #TMPORDTBL
   (seqno       INT,
    Orderkey    NVARCHAR(10))

    INSERT INTO #TMPORDTBL
    (
        seqno,
        Orderkey
    )
SELECT ROW_NUMBER() OVER (ORDER BY OH.loadkey,OH.OrderKey)  AS seqno
      , OH.OrderKey AS Orderkey
   FROM ORDERS OH WITH (NOLOCK)
   WHERE OH.LoadKey=@c_loadkey
   ORDER BY OH.OrderKey
   
   SELECT PD.loc AS LOC,PD.OrderKey AS Orderkey,PD.sku AS sku,SUM(PD.qty) AS qty ,
       SUBSTRING(S.RETAILSKU,1 , charindex('-',S.RETAILSKU)) AS style,
       SUBSTRING(SUBSTRING(S.RETAILSKU, charindex('-',S.RETAILSKU)+1,20),1 , charindex('-',SUBSTRING(S.RETAILSKU, charindex('-',S.RETAILSKU)+1,20))) AS color,
       SUBSTRING(SUBSTRING(S.RETAILSKU,charindex('-',S.RETAILSKU)+1 ,20 ),charindex('-',SUBSTRING(S.RETAILSKU,charindex('-',S.RETAILSKU)+1 ,20 ))+1 ,20 ) AS SSize,
       S.descr AS SDESCR,TMP.seqno AS ordseq
--FROM ORDERS OH WITH (NOLOCK)
--JOIN orderdetail OD (NOLOCK) ON OD.OrderKey = OH.OrderKey
FROM #TMPORDTBL TMP
JOIN dbo.PICKDETAIL PD WITH (NOLOCK) ON PD.Orderkey = TMP.Orderkey --AND PD.storerkey = OD.storerkey AND PD.sku=OD.sku
JOIN SKU S WITH (NOLOCK) ON S.storerkey = PD.storerkey AND S.sku = PD.sku 
--WHERE OH.LoadKey=@c_loadkey
GROUP BY PD.loc,PD.sku,PD.OrderKey,
       SUBSTRING(S.RETAILSKU,1 , charindex('-',S.RETAILSKU)),
       SUBSTRING(SUBSTRING(S.RETAILSKU, charindex('-',S.RETAILSKU)+1,20),1 , charindex('-',SUBSTRING(S.RETAILSKU, charindex('-',S.RETAILSKU)+1,20))),
      SUBSTRING(SUBSTRING(S.RETAILSKU,charindex('-',S.RETAILSKU)+1 ,20 ),charindex('-',SUBSTRING(S.RETAILSKU,charindex('-',S.RETAILSKU)+1 ,20 ))+1 ,20 ),
      S.DESCR,tmp.seqno
ORDER BY PD.loc,PD.sku,PD.OrderKey
   GOTO QUIT;
  
END -- procedure
QUIT:

   IF OBJECT_ID('tempdb..#TMPORDTBL') IS NOT NULL
      DROP TABLE #TMPORDTBL


GO