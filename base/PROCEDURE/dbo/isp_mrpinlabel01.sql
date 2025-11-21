SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_MRPINLabel01                                        */
/* Creation Date: 25-APR-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-1625 - SG Logitech MRP Wholesale Carton Label           */
/*        :                                                             */
/* Called By: r_dw_carton_MRPIN_Label01_1                               */
/*          : r_dw_carton_MRPIN_Label01_2                               */
/*                                                                      */
/* PVCS Version: 1.4                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 04-JUL-2017 Wan01    1.1   WMS-2332 - Changes to Logitech Packing    */
/* 23-Aug-2019 CSCHONG  1.2   WMS-10266 revised field logic (CS01)      */
/* 25-May-2022 Mingle   1.3   WMS-19712 modify logic (ML01)             */
/* 06-Jul-2022 WLChooi  1.4   Bug Fix - Use Innerpack instead of Casecnt*/
/*                            (WL01)                                    */
/* 06-Jul-2022 WLChooi  1.4   DevOps Combine Script                     */
/************************************************************************/
CREATE PROC [dbo].[isp_MRPINLabel01]
           @c_PickSlipNo         NVARCHAR(10)
         , @c_CartonNoStart      NVARCHAR(10)
         , @c_CartonNoEnd        NVARCHAR(10) 
         , @c_SourceDW           NVARCHAR(50) 

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

         , @n_MaxSurfaceFr    FLOAT 
         , @n_MaxSurfaceTo    FLOAT 

         , @n_RowRef          INT
         , @n_NoOfCopy        INT

   SET @n_StartTCnt = @@TRANCOUNT

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END

   IF OBJECT_ID('tempdb..#TMP_PACKSKU','U') IS NOT NULL
      DROP TABLE #TMP_PACKSKU;

   CREATE TABLE #TMP_PACKSKU 
      (  RowRef         INT   IDENTITY(1,1) PRIMARY KEY
      ,  Orderkey       NVARCHAR(10)  
      ,  PickSlipNo     NVARCHAR(10)   
      ,  CartonNo       INT  
      ,  Storerkey      NVARCHAR(15)
      ,  Sku            NVARCHAR(10)
      ,  MaxSurface     FLOAT
      ,  CaseCnt        FLOAT
      ,  InnerPack      FLOAT
      ,  Qty            INT
      ,  SI_ExtFld21    NVARCHAR(4000)  NULL  DEFAULT('')
      )

   IF OBJECT_ID('tempdb..#TMP_PRNCOPY','U') IS NOT NULL
      DROP TABLE #TMP_PRNCOPY;

   CREATE TABLE #TMP_PRNCOPY
      (  RowRef         INT             NOT NULL DEFAULT('')
      )

   IF @c_SourceDW = 'r_dw_carton_mrpin_label01_1'
   BEGIN
      SET @n_MaxSurfaceFr = 0.00
      SET @n_MaxSurfaceTo = 2500.00
   END
   
   IF @c_SourceDW = 'r_dw_carton_mrpin_label01_2'
   BEGIN
      SET @n_MaxSurfaceFr = 2500.01
      SET @n_MaxSurfaceTo = 9999999.99
   END

   INSERT INTO #TMP_PACKSKU
      (  Orderkey
      ,  PickSlipNo
      ,  CartonNo
      ,  Storerkey
      ,  Sku
      ,  MaxSurface
      ,  CaseCnt
      ,  InnerPack
      ,  Qty
      )
   SELECT DISTINCT   
         PACKHEADER.Orderkey
      ,  PACKHEADER.PickSlipNo    
      ,  PACKDETAIL.CartonNo              
      ,  PACKDETAIL.Storerkey
      ,  PACKDETAIL.Sku
      ,  MaxSurface = CASE WHEN (PACK.WidthUOM2 * PACK.LengthUOM2) > (PACK.WidthUOM2 * PACK.HeightUOM2) 
                           AND  (PACK.WidthUOM2 * PACK.LengthUOM2) > (PACK.LengthUOM2* PACK.HeightUOM2)
                           THEN (PACK.WidthUOM2 * PACK.LengthUOM2)
                           WHEN (PACK.WidthUOM2 * PACK.HeightUOM2) > (PACK.LengthUOM2* PACK.HeightUOM2)
                           AND  (PACK.WidthUOM2 * PACK.HeightUOM2) > (PACK.WidthUOM2 * PACK.LengthUOM2)
                           THEN (PACK.WidthUOM2 * PACK.HeightUOM2)
                           ELSE (PACK.LengthUOM2* PACK.HeightUOM2)
                           END
      --,  MaxSurface = CASE WHEN (PACK.WidthUOM2 * PACK.LengthUOM2) > (PACK.WidthUOM2 * PACK.HeightUOM2)
      --                     THEN (PACK.WidthUOM2 * PACK.LengthUOM2)
      --                     WHEN (PACK.WidthUOM2 * PACK.LengthUOM2) > (PACK.LengthUOM2* PACK.HeightUOM2)
      --                     THEN (PACK.WidthUOM2 * PACK.LengthUOM2)
      --                     WHEN (PACK.WidthUOM2 * PACK.HeightUOM2) > (PACK.LengthUOM2* PACK.HeightUOM2)
      --                     THEN (PACK.WidthUOM2 * PACK.HeightUOM2)
      --                     ELSE (PACK.LengthUOM2* PACK.HeightUOM2)
      --                     END
      ,  PACK.CaseCnt
      ,  PACK.InnerPack
      ,  Qty = SUM(PACKDETAIL.QTY)
   FROM PACKHEADER   WITH (NOLOCK)
   JOIN PACKDETAIL   WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)
   JOIN SKU          WITH (NOLOCK) ON (PACKDETAIL.Storerkey = SKU.Storerkey)
                                   AND(PACKDETAIL.Sku = SKU.Sku)
   JOIN PACK         WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
   JOIN ORDERS       WITH (NOLOCK) ON (PACKHEADER.Orderkey = ORDERS.Orderkey)
   LEFT JOIN STORER ST WITH (NOLOCK) ON ST.Storerkey = ORDERS.Consigneekey AND ST.consigneefor = 'LOGITECH'     --CS01
   WHERE PACKDETAIL.PickSlipNo = @c_PickSlipNo
   AND   PACKDETAIL.CartonNo >= CONVERT(INT, @c_CartonNoStart) 
   AND   PACKDETAIL.CartonNo <= CONVERT(INT, @c_CartonNoEnd)
  -- AND   ORDERS.C_Country = 'IN'                                                     --CS01
   AND   ST.Notes2 = 'MRP'                                                             --CS01 
   AND   ORDERS.OrderGroup NOT IN ('S01')
   AND   ORDERS.UserDefine10 NOT IN ('NO')                                             --(Wan01)
   AND   ORDERS.Consigneekey NOT IN ('218793')
   AND   PACK.InnerPack > 0
   AND   PACKDETAIL.QTY >= PACK.InnerPack 
   GROUP BY PACKHEADER.Orderkey
         ,  PACKHEADER.PickSlipNo    
         ,  PACKDETAIL.CartonNo              
         ,  PACKDETAIL.Storerkey
         ,  PACKDETAIL.Sku 
         ,  PACK.WidthUOM2 
         ,  PACK.LengthUOM2
         ,  PACK.HeightUOM2
         ,  PACK.CaseCnt
         ,  PACK.InnerPack
   
   IF (  SELECT COUNT(1) FROM #TMP_PACKSKU  
         WHERE PickSlipNo = @c_PickSlipNo
         AND   MaxSurface BETWEEN @n_MaxSurfaceFr AND @n_MaxSurfaceTo
      ) = 0
   BEGIN
      GOTO QUIT_SP
   END

   
   UPDATE TMP
   SET   SI_ExtFld21 = ISNULL(RTRIM(SI.ExtendedField21),'')
   FROM #TMP_PACKSKU TMP WITH (NOLOCK) 
   JOIN SKUINFO      SI  WITH (NOLOCK) ON (TMP.Storerkey = SI.Storerkey)
                                       AND(TMP.Sku  = SI.Sku )
   WHERE TMP.PickSlipNo = @c_PickSlipNo
   AND   TMP.MaxSurface BETWEEN @n_MaxSurfaceFr AND @n_MaxSurfaceTo 
  
   DECLARE CUR_PSLIP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RowRef
         ,NoOfCopy = FLOOR(Qty / InnerPack)
   FROM #TMP_PACKSKU TMP
   WHERE TMP.PickSlipNo = @c_PickSlipNo
   AND   TMP.MaxSurface BETWEEN @n_MaxSurfaceFr AND @n_MaxSurfaceTo

   OPEN CUR_PSLIP
   
   FETCH NEXT FROM CUR_PSLIP INTO @n_RowRef
                                 ,@n_NoOfCopy

   WHILE @@FETCH_STATUS <> -1  
   BEGIN
 
      WHILE @n_NoOfCopy > 0 
      BEGIN
         INSERT INTO #TMP_PRNCOPY
            (  RowRef 
            )
         VALUES 
            (  @n_RowRef
            )
         SET @n_NoOfCopy = @n_NoOfCopy - 1
      END

      FETCH NEXT FROM CUR_PSLIP INTO @n_RowRef
                                    ,@n_NoOfCopy
   END
   CLOSE CUR_PSLIP
   DEALLOCATE CUR_PSLIP
QUIT_SP:

   SELECT ImportBy   = 'Name and Address of Importer: ' 
                     + ISNULL(RTRIM(CSG.Company ),'')  + CHAR(13)
                     + ISNULL(RTRIM(CSG.Address1),'')  + ' '
                     + ISNULL(RTRIM(CSG.Address2),'')  + ' '
                     + ISNULL(RTRIM(CSG.Address3),'')  + ' '
                     + ISNULL(RTRIM(CSG.Address4),'')  + ' '
                     + ISNULL(RTRIM(CSG.City),'')      + ' '
                     + ISNULL(RTRIM(CSG.State),'')     + ' '
                     + ISNULL(RTRIM(CSG.Zip),'')       + ' '
                     + ISNULL(RTRIM(CSG.Country),'')  
      ,  RegisteredBy= 'Registered Address: ' 
                     + ISNULL(RTRIM(CSG.B_Company),'') + ' '
                     + ISNULL(RTRIM(CSG.B_Address1),'')+ ' '
                     + ISNULL(RTRIM(CSG.B_Address2),'')+ ' '
                     + ISNULL(RTRIM(CSG.B_Address3),'')+ ' '
                     + ISNULL(RTRIM(CSG.B_Address4),'')+ ' '
                     + ISNULL(RTRIM(CSG.B_City),'')    + ' '
                     + ISNULL(RTRIM(CSG.B_State),'')   + ' '
                     + ISNULL(RTRIM(CSG.B_Zip),'')    + ' '
                     + ISNULL(RTRIM(CSG.B_Country),'') 
      ,  ExtFld21 = 'Generic Name: ' + TMP.SI_ExtFld21
      ,  Sku = 'VPN: ' + TMP.Sku
      --,  Qty = 'Net Quantity: ' + RTRIM(CONVERT( NVARCHAR(10), TMP.InnerPack )) + 'N'
      ,  Qty = 'Net Quantity: ' + RTRIM(CONVERT( NVARCHAR(10), TMP.InnerPack )) + ' Unit'	--ML01   --WL01
      ,  IMPBy_UL = '______________________________'
      ,  RGSTBy_UL= '____________________'
   FROM #TMP_PACKSKU TMP   
   JOIN #TMP_PRNCOPY TMP_PRN ON (TMP.RowRef = TMP_PRN.RowRef)   
   JOIN ORDERS     OH  WITH (NOLOCK) ON (TMP.Orderkey = OH.Orderkey)
   JOIN STORER     ST  WITH (NOLOCK) ON (OH.Storerkey = ST.Storerkey)
   LEFT JOIN STORER  CSG WITH (NOLOCK) ON (OH.Consigneekey = CSG.Storerkey)
                                       AND(CSG.Type = '2')
   WHERE TMP.PickSlipNo = @c_PickSlipNo
   AND   TMP.MaxSurface BETWEEN @n_MaxSurfaceFr AND @n_MaxSurfaceTo

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END

END -- procedure

GO