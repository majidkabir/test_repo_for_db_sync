SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_StockOut_Summ_rpt                                   */
/* Creation Date: 18-JUL-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-5576 - CN_Shaklee_Stockout_Summary_Report               */
/*        :                                                             */
/* Called By:  r_dw_stockout_summ_rpt                                   */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_StockOut_Summ_rpt] --'P008571995'
            @c_Orderkey        NVARCHAR(10) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
            @n_StartTCnt      INT
         ,  @n_Continue       INT 
         ,  @c_Facility       NVARCHAR(10)              
         ,  @c_Storerkey      NVARCHAR(15)             
 
   SET @c_Facility = ''

   --SELECT @c_Facility = ISNULL(RTRIM(CL.Short),'')
   --FROM CODELKUP CL WITH (NOLOCK)
   --WHERE CL.ListName = 'SHAKLEEFAC'
   --AND   CL.Code = 'StorageName'

QUIT_SP:

   SELECT SortBy     = ROW_NUMBER() OVER (   ORDER BY OH.Orderkey
                                                    , RTRIM(SKU.Sku)
                                          )
         ,RowNo      = ROW_NUMBER() OVER (   PARTITION BY OH.Orderkey
                                             ORDER BY OH.Orderkey
                                                    , RTRIM(SKU.Sku)
                                             )
         ,Facility   = ISNULL(RTRIM(CL.UDF01),'')--@c_Facility
         ,Storerkey  = OH.Storerkey
         ,LFWMSNo    = OH.Orderkey     
         ,OrderNo    = ISNULL(RTRIM(OH.ExternOrderkey),'')
         ,SaleNo     = ISNULL(RTRIM(OH.M_Company),'')
         ,OrderDate  = OH.OrderDate
         ,Sku        = RTRIM(SKU.Sku)
         ,SkuDescr   = ISNULL(RTRIM(SKU.Descr),'')       
         ,OriginalQty= OD.OriginalQty
         ,StockOutQty= OD.OriginalQty - SUM(PD.Qty)
   FROM ORDERS       OH WITH (NOLOCK)
   JOIN ORDERDETAIL  OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
   JOIN PICKDETAIL   PD WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey)
                                      AND(OD.OrderLineNumber = PD.OrderLineNumber)
   JOIN SKU         SKU WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)
                                      AND(PD.Sku = SKU.Sku)
   LEFT JOIN CODELKUP CL WITH (NOLOCK)ON (CL.ListName = 'SHAKLEEFAC')
                                      AND(CL.Storerkey= OH.Storerkey)
                                      AND(CL.Short= OH.Facility)
   WHERE OH.Orderkey = @c_Orderkey
   AND   PD.Status >= '5'
   GROUP BY ISNULL(RTRIM(CL.UDF01),'')
         ,  OH.Storerkey
         ,  OH.Orderkey  
         ,  ISNULL(RTRIM(OH.ExternOrderkey),'')
         ,  ISNULL(RTRIM(OH.M_Company),'')
         ,  OH.OrderDate
         ,  RTRIM(SKU.Sku) 
         ,  ISNULL(RTRIM(SKU.Descr),'')              
         ,  OD.OriginalQty
   HAVING OD.OriginalQty - SUM(PD.Qty) > 0
END -- procedure

GO