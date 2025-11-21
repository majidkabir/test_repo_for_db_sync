SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_GetPackdetail_Summary                               */
/* Creation Date: 2020-04-07                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-12722 - SG - PMI - Packing [CR]                         */
/*        : Change DW Select to Store Procedure                         */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2020-05-22  Wan01    1.1   Fixed. Conso pack Allocation Qty incorrect*/
/* 2020-06-03  Wan02    1.2   WMS-13491 - SG - PMI - Packing [CR]       */
/* 2020-07-02  Wan03    1.3   Fixed. Not to show Total for storerconfig */ 
/*                            'PackbyDropID' not turn on                */
/************************************************************************/
CREATE PROC [dbo].[isp_GetPackdetail_Summary]
           @c_PickslipNo      NVARCHAR(10)
         , @c_DropID          NVARCHAR(20)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt          INT            = @@TRANCOUNT
         , @c_Orderkey           NVARCHAR(10)   = ''
         , @c_Loadkey            NVARCHAR(10)   = ''
         , @c_Storerkey          NVARCHAR(15)   = ''
         , @c_Facility           NVARCHAR(5)    = ''

         , @c_ScanAsPack         NVARCHAR(30)   = '0'
         , @c_PackByDropID       NVARCHAR(30)   = '0'  
         
   --(Wan02) - START
   DECLARE @t_PACKSUMMARY TABLE
         ( RowID        INT     NOT NULL IDENTITY(1,1)  PRIMARY KEY
         , RecType      NVARCHAR(10)  NOT NULL DEFAULT('')  
         , Storerkey    NVARCHAR(15)  NOT NULL DEFAULT('')
         , Sku          NVARCHAR(20)  NOT NULL DEFAULT('') 
         , PickedQty    INT           NOT NULL DEFAULT(0) 
         , PackedQty    INT           NOT NULL DEFAULT(0) 
         , OtherQty     INT           NULL
         , Orddetlot1   NVARCHAR(15)  NOT NULL DEFAULT('')
         , ScanAsPack   NVARCHAR(30)  NOT NULL DEFAULT('')
         , Casecnt      FLOAT         NULL 
         , AltSku       NVARCHAR(20)  NOT NULL DEFAULT('') 
         , SkuDescr     NVARCHAR(60)  NOT NULL DEFAULT('') 
         )
   --(Wan02) - END

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   IF OBJECT_ID('tempdb..#TMP_ORDERS','u') IS NOT NULL
   BEGIN
      DROP TABLE #TMP_ORDERS
   END

   CREATE TABLE #TMP_ORDERS
   (  Orderkey    NVARCHAR(10)   NOT NULL DEFAULT('') PRIMARY KEY
   )

   IF OBJECT_ID('tempdb..#TMP_ORDERSKU','u') IS NOT NULL
   BEGIN
      DROP TABLE #TMP_ORDERSKU
   END

   CREATE TABLE #TMP_ORDERSKU
   (  Orderkey    NVARCHAR(10)   NOT NULL DEFAULT('') 
   ,  Storerkey   NVARCHAR(15)   NOT NULL DEFAULT('')
   ,  Sku         NVARCHAR(20)   NOT NULL DEFAULT('') 
   ,  PickedQty   INT            NOT NULL DEFAULT(0)
   ,  Orddetlot1  NVARCHAR(18)   NOT NULL DEFAULT('')
   )

   IF OBJECT_ID('tempdb..#TMP_PACK','u') IS NOT NULL
   BEGIN
      DROP TABLE #TMP_PACK
   END

   CREATE TABLE #TMP_PACK
   (  Storerkey   NVARCHAR(15)   NOT NULL DEFAULT('')
   ,  Sku         NVARCHAR(20)   NOT NULL DEFAULT('') PRIMARY KEY
   ,  PackedQty   INT            NOT NULL DEFAULT(0)
   )
   
   SELECT @c_Orderkey = PH.Orderkey
         ,@c_Loadkey  = ISNULL(PH.ExternOrderKey,'')
   FROM PICKHEADER PH WITH (NOLOCK) 
   WHERE PH.PickHeaderkey = @c_PickSlipNo

   IF @c_Orderkey <> ''
   BEGIN
      SELECT @c_Storerkey = OH.Storerkey
            ,@c_Facility  = OH.Facility
      FROM ORDERS OH WITH (NOLOCK)
      WHERE OH.Orderkey = @c_Orderkey

      SELECT @c_ScanAsPack = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'SCANASPACK')

      INSERT INTO #TMP_ORDERS
         (  Orderkey )
      VALUES ( @c_Orderkey )
   END
   ELSE
   BEGIN
      INSERT INTO #TMP_ORDERS
         (  Orderkey )
      SELECT LP.Orderkey
      FROM LOADPLANDETAIL LP WITH (NOLOCK)
      WHERE LP.LoadKey = @c_Loadkey

      SELECT TOP 1 
             @c_Storerkey = OH.Storerkey
            ,@c_Facility  = OH.Facility
      FROM #TMP_ORDERS O
      JOIN ORDERS OH WITH (NOLOCK) ON O.Orderkey = OH.Orderkey
      ORDER BY O.Orderkey
   END

   SELECT @c_PackByDropID = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'PackByDropID')

   IF @c_PackByDropID = '1' AND @c_DropID <> ''
   BEGIN
      INSERT INTO #TMP_ORDERSKU
      (  Orderkey
      ,  Storerkey
      ,  Sku
      ,  PickedQty
      ,  Orddetlot1
      )
      SELECT Orderkey = MIN(OD.Orderkey)     --(Wan02)
            ,OD.StorerKey   
            ,Sku        = UPPER(OD.Sku)    
            ,PickedQty  = ISNULL(SUM(PD.Qty),0)    
            ,Orddetlot1 = ISNULL(MAX(OD.Lottable01),0)
      FROM #TMP_ORDERS  O
      JOIN ORDERDETAIL  OD WITH (NOLOCK) ON OD.Orderkey = O.Orderkey
      JOIN PICKDETAIL   PD WITH (NOLOCK) ON OD.Orderkey = PD.Orderkey AND OD.OrderLineNumber = PD.OrderLineNumber
      WHERE PD.DropID = @c_DropID
      --GROUP BY OD.Orderkey
      GROUP BY OD.StorerKey                  --(Wan02) -- Do not group by orderkey, error if it a consolidated pack by dropid 
            ,  OD.Sku
      HAVING SUM(PD.Qty) > 0

      INSERT INTO #TMP_PACK
         (  Storerkey
         ,  Sku
         ,  PackedQty
         )
      SELECT PD.Storerkey
            ,PD.Sku
            ,PackedQty = ISNULL(SUM(PD.Qty),0)
      FROM PACKDETAIL PD WITH (NOLOCK)
      WHERE PD.PickSlipNo = @c_PickslipNo
      AND   PD.DropID = @c_DropID
      GROUP BY PD.Storerkey
            ,  PD.Sku
   END
   ELSE
   BEGIN
      INSERT INTO #TMP_ORDERSKU
      (  Orderkey
      ,  Storerkey
      ,  Sku
      ,  PickedQty
      ,  Orddetlot1
      )
      SELECT Orderkey = MIN(OD.Orderkey)     --(Wan01)
            ,OD.StorerKey   
            ,Sku        = UPPER(OD.Sku)    
            ,PickedQty  = ISNULL(SUM(OD.QtyAllocated+OD.QtyPicked+OD.ShippedQty),0)    
            ,Orddetlot1 = ISNULL(MAX(OD.Lottable01),0)
      FROM #TMP_ORDERS  O
      JOIN ORDERDETAIL  OD WITH (NOLOCK) ON OD.Orderkey = O.Orderkey
      --GROUP BY OD.Orderkey                 --(Wan01)
      GROUP BY OD.StorerKey                 --(Wan01)
            ,  OD.Sku
      HAVING SUM(OD.QtyAllocated+OD.QtyPicked+OD.ShippedQty) > 0

      INSERT INTO #TMP_PACK
         (  Storerkey
         ,  Sku
         ,  PackedQty
         )
      SELECT PD.Storerkey
            ,PD.Sku
            ,PackedQty = ISNULL(SUM(PD.Qty),0)
      FROM PACKDETAIL PD WITH (NOLOCK)
      WHERE PD.PickSlipNo = @c_PickslipNo
      GROUP BY PD.Storerkey
            ,  PD.Sku
   END

   --(Wan02) - START
   INSERT INTO @t_PACKSUMMARY
      (  RecType
      ,  Storerkey    
      ,  Sku          
      ,  PickedQty    
      ,  PackedQty    
      ,  OtherQty     
      ,  Orddetlot1   
      ,  ScanAsPack   
      ,  Casecnt      
      ,  AltSku       
      ,  SkuDescr     
      )
   SELECT RecType = 'data'
      ,  OS.StorerKey   
      ,  OS.Sku    
      ,  OS.PickedQty
      ,  PackedQty  = ISNULL(P.PackedQty,0) 
      ,  OtherQty   = 0
      ,  Orddetlot1 = CASE WHEN @c_Orderkey = '' THEN '' ELSE OS.Orddetlot1 END
      ,  ScanAsPack = @c_ScanAsPack 
      ,  PACK.Casecnt
      ,  AltSku  = ISNULL(SKU.AltSku,'') 
      ,  SkuDescr= ISNULL(SKU.Descr,'')               --(Wan02)

   FROM #TMP_ORDERSKU  OS
   JOIN SKU         WITH (NOLOCK) ON OS.Storerkey = SKU.Storerkey AND OS.Sku = SKU.Sku 
   JOIN PACK        WITH (NOLOCK) ON SKU.Packkey = PACK.Packkey
   LEFT JOIN #TMP_PACK P ON OS.Storerkey = P.Storerkey AND OS.Sku = P.Sku
   ORDER BY OS.Storerkey
         ,  OS.Sku

   --(Wan03) - START
   IF @c_PackByDropID = '1' AND @c_DropID <> ''
   BEGIN
      INSERT INTO @t_PACKSUMMARY
         (  RecType
         ,  Storerkey    
         ,  Sku          
         ,  PickedQty    
         ,  PackedQty    
         ,  OtherQty     
         ,  Orddetlot1   
         ,  ScanAsPack   
         ,  Casecnt      
         ,  AltSku       
         ,  SkuDescr     
         )
      SELECT RecType = 'summary'
            ,Storerkey = ''
            ,Sku = 'Total: '
            ,TotalPickedQty = ISNULL(SUM(OS.PickedQty),0)
            ,TotolPackedQty = ISNULL(SUM(P.PackedQty),0) 
            ,OtherQty   = NULL
            ,Orddetlot1 = ''
            ,ScanAsPack = ''
            ,Casecnt    = NULL
            ,AltSku     = ''
            ,SkuDescr   = ''
      FROM #TMP_ORDERSKU  OS
      LEFT JOIN #TMP_PACK P ON OS.Storerkey = P.Storerkey AND OS.Sku = P.Sku
   END 
   --(Wan03) - END
   
   SELECT Storerkey    
         ,Sku          
         ,PickedQty    
         ,PackedQty    
         ,OtherQty     
         ,Orddetlot1   
         ,ScanAsPack   
         ,Casecnt      
         ,AltSku       
         ,SkuDescr 
         ,RecType
   FROM @t_PACKSUMMARY
   ORDER BY RowID
   --(Wan02) - END
   
QUIT_SP:
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO