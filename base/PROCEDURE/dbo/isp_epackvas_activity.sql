SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_EPackVas_Activity                              */  
/* Creation Date: 12-JUL-2016                                           */  
/* Copyright: LF                                                        */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-2306 - CN-Nike SDC WMS ECOM Packing CR                  */  
/*                                                                      */  
/* Called By: d_dw_packvas_activity_ecom                                */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */
/* 04-OCT-2017 Wan01    1.1   WMS-3086 - [CN] NIKE CRW Plus Packing for */
/*                            VAS                                       */
/* 19-DEC-2017 Wan02    1.2   WMS-3657- NIKE CRW Plus SKU VAS Packing CR*/
/*                            Fixed: Duplicate VAS activity for Same Sku*/
/*                            in multi Shipment orderkey                */
/************************************************************************/   
CREATE PROCEDURE [dbo].[isp_EPackVas_Activity]
      @c_Orderkey    NVARCHAR(15)         --(Wan01) Documentkey: Orderkey or 'L' + Loadkey 
   ,  @c_Storerkey   NVARCHAR(15)  
   ,  @c_Sku         NVARCHAR(20) = ''
AS  
BEGIN  
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF 
   
   DECLARE  
           @n_StartTCnt          INT
         , @n_Continue           INT 

         , @b_Success            INT           
         , @n_err                INT     
         , @c_errmsg             NVARCHAR(255)  

         , @c_SQL                NVARCHAR(4000)
         , @c_SQLArgument        NVARCHAR(4000)
      
         , @n_QtyPicked          INT
         , @n_QtyPacked          INT
         , @c_Facility           NVARCHAR(5)
         , @c_PickSlipNo         NVARCHAR(10)
         , @c_Loadkey            NVARCHAR(10)      --(Wan01)
         , @c_OrderLineNumber    NVARCHAR(5)
         , @c_OrderLineNo        NVARCHAR(5)
         , @c_OrderNo            NVARCHAR(10)      --(Wan02)

         , @c_EPACKVASActivity   NVARCHAR(30)    

         , @cur_OD               CURSOR          

   SET @n_StartTCnt = @@TRANCOUNT

   CREATE TABLE #TMP_VASActivity
      (  Orderkey          NVARCHAR(10)   NULL DEFAULT('')
      ,  OrderLineNumber   NVARCHAR(5)    NULL DEFAULT('')
      ,  Storerkey         NVARCHAR(15)   NULL DEFAULT('')
      ,  Sku               NVARCHAR(20)   NULL DEFAULT('')
      ,  Qty               INT            NULL DEFAULT(0)
      ,  Activity          NVARCHAR(1000) NULL DEFAULT('')
      ,  Checked           CHAR(1)        NULL DEFAULT('N')
      )
      
   SET @c_Sku = ISNULL(RTRIM(@c_Sku),'') 
   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END
                                        
   IF @c_Orderkey = ''
   BEGIN
      GOTO QUIT_SP
   END    

   --(Wan01) -- START
   IF LEFT(@c_Orderkey,1) = 'L'
   BEGIN
      SET @c_Loadkey = RIGHT(@c_Orderkey,10)
      SET @c_Orderkey= ''

      SET @c_Facility = ''
      SELECT TOP 1 @c_Facility = Facility
      FROM ORDERS WITH (NOLOCK)
      WHERE Loadkey = @c_Loadkey
   END
   ELSE
   BEGIN
      SET @c_Facility = ''
      SELECT @c_Facility = Facility
      FROM ORDERS WITH (NOLOCK)
      WHERE Orderkey = @c_Orderkey
   END
   --(Wan01) -- END

   SET @b_Success = 1
   SET @c_EPACKVASActivity = ''
   EXEC nspGetRight      
         @c_Facility  = @c_Facility     
      ,  @c_StorerKey = @c_StorerKey      
      ,  @c_sku       = NULL      
      ,  @c_ConfigKey = 'EPACKVASActivity'      
      ,  @b_Success   = @b_Success           OUTPUT      
      ,  @c_authority = @c_EPACKVASActivity  OUTPUT      
      ,  @n_err       = @n_err               OUTPUT      
      ,  @c_errmsg    = @c_errmsg            OUTPUT

   IF @b_Success = 0
   BEGIN
      GOTO QUIT_SP
   END

   IF @c_EPACKVASActivity <> '1'
   BEGIN
      GOTO QUIT_SP
   END

   SET @c_OrderLineNumber = ''
   IF @c_Sku <> ''
   BEGIN
      SET @c_PickSlipNo = ''
      --(Wan01) - START
      IF @c_Orderkey <> ''
      BEGIN
         SELECT TOP 1 @c_PickSlipNo = PickSlipNo
         FROM PACKHEADER WITH (NOLOCK)
         WHERE Orderkey = @c_Orderkey
      END  

      IF @c_PickSlipNo = ''  
      BEGIN
         SELECT TOP 1 @c_PickSlipNo = PickSlipNo
         FROM PACKHEADER WITH (NOLOCK)
         WHERE Loadkey = @c_Loadkey
      END

      IF @c_PickSlipNo = ''
      BEGIN
         GOTO QUIT_SP
      END
      --(Wan01) - END

      SET @n_QtyPacked = 0
      IF @c_PickSlipNo <> ''
      BEGIN
         SELECT @n_QtyPacked = ISNULL(SUM(PD.Qty),0)
         FROM PACKDETAIL PD WITH (NOLOCK)
         WHERE PD.PickSlipNo = @c_PickslipNo
         AND   PD.Storerkey  = @c_Storerkey
         AND   PD.SKU        = @c_Sku
      END

      --(Wan01) - START
      IF @c_Orderkey = ''
      BEGIN 
         SET @cur_OD = CURSOR FAST_FORWARD READ_ONLY FOR      
            SELECT Orderkey = OD.Orderkey                            --(Wan02)
                  ,OrderLineNumber = OD.OrderLineNumber
                  ,QtyPicked = OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty
            FROM ORDERDETAIL    OD  WITH (NOLOCK)
            JOIN ORDERDETAILREF ODR WITH (NOLOCK) ON (OD.Orderkey = ODR.Orderkey)
                                                  AND(OD.OrderLineNumber = ODR.OrderLineNumber)
            JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON (OD.Orderkey = LPD.Orderkey)
            WHERE LPD.Loadkey  = @c_Loadkey 
            AND   OD.Storerkey = @c_Storerkey
            AND   OD.SKU       = @c_Sku
            AND   OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty > 0
            AND   ODR.RefType  = 'PI'
            GROUP BY OD.Orderkey                                     --(Wan02)
                  ,  OD.OrderLineNumber
                  ,  OD.QtyAllocated
                  ,  OD.QtyPicked
                  ,  OD.ShippedQty
            ORDER BY OD.Orderkey                                     --(Wan02)
                  ,  OD.OrderLineNumber 
      END
      ELSE
      BEGIN
         SET @cur_OD = CURSOR FAST_FORWARD READ_ONLY FOR      
            SELECT Orderkey = OD.Orderkey                            --(Wan02)
                  ,OrderLineNumber = OD.OrderLineNumber
                  ,QtyPicked = OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty
            FROM ORDERDETAIL    OD  WITH (NOLOCK)
            JOIN ORDERDETAILREF ODR WITH (NOLOCK) ON (OD.Orderkey = ODR.Orderkey)
                                                  AND(OD.OrderLineNumber = ODR.OrderLineNumber)
            WHERE OD.Orderkey  = @c_Orderkey
            AND   OD.Storerkey = @c_Storerkey
            AND   OD.SKU       = @c_Sku
            AND   OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty > 0
            AND   ODR.RefType  = 'PI'
            GROUP BY OD.Orderkey                                     --(Wan02)
                  ,  OD.OrderLineNumber
                  ,  OD.QtyAllocated
                  ,  OD.QtyPicked
                  ,  OD.ShippedQty
            ORDER BY OD.Orderkey                                     --(Wan02)
                  ,  OD.OrderLineNumber 
      END
      --(Wan01) - END

      OPEN @cur_OD
      FETCH NEXT FROM @cur_OD INTO @c_OrderNo                        --(Wan02)
                                 , @c_OrderLineNo
                                 , @n_QtyPicked
      WHILE @@FETCH_STATUS <> -1 AND @n_QtyPacked >= 0
      BEGIN
         SET @c_Orderkey = @c_OrderNo                                --(Wan02)
         SET @c_OrderLineNumber = @c_OrderLineNo

         SET @n_QtyPacked = @n_QtyPacked - @n_QtyPicked

         IF @n_QtyPacked = 0                                         --(Wan02)
         BEGIN                                                       --(Wan02)
            SET @n_QtyPacked = -1                                    --(Wan02)
         END                                                         --(Wan02)    

         FETCH NEXT FROM @cur_OD INTO @c_OrderNo                     --(Wan02)
                                    , @c_OrderLineNo
                                    , @n_QtyPicked
      END

      IF @c_OrderLineNumber = '' 
      BEGIN
         GOTO QUIT_SP
      END
   END
   
   SET @c_SQL  = N' SELECT DISTINCT'
               + '  OD.Orderkey'
               + ' ,OD.OrderLineNumber'
               + ' ,OD.Storerkey'
               + ' ,OD.Sku'
               + ' ,Qty = CASE WHEN @c_Sku = '''' THEN OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty ELSE 1 END'
               + ' ,VASActivity = ISNULL(RTRIM(ODR.Note1),'''')'
               + ' FROM ORDERDETAIL    OD  WITH (NOLOCK)'
               + ' JOIN ORDERDETAILREF ODR WITH (NOLOCK) ON (OD.Orderkey = ODR.Orderkey)'
               +                                       ' AND(OD.OrderLineNumber = ODR.OrderLineNumber)'
               + CASE WHEN @c_Orderkey = ''                                                           --(Wan01)
                      THEN 'JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON (OD.Orderkey = LPD.Orderkey)'    --(Wan01)
                      ELSE ''                                                                         --(Wan01)
                      END                                                                             --(Wan01)
               + CASE WHEN @c_Orderkey = ''                    --(Wan01)
                      THEN ' WHERE LPD.Loadkey = @c_Loadkey'   --(Wan01)
                      ELSE ' WHERE OD.Orderkey = @c_Orderkey'  --(Wan01)
                      END                                      --(Wan01)
               + CASE WHEN @c_Sku = '' 
                      THEN '' 
                      ELSE ' AND OD.Orderkey = @c_Orderkey'    --(Wan02)
               +           ' AND OD.OrderLineNumber = @c_OrderLineNumber AND OD.Sku = @c_Sku'
                      END
               + ' ORDER BY OD.Orderkey, OD.OrderLineNumber'   --(Wan02)

   SET @c_SQLArgument = N'@c_Loadkey         NVARCHAR(10)'     --(Wan01)
                      + ',@c_Orderkey        NVARCHAR(10)'
                      + ',@c_OrderLineNumber NVARCHAR(5)'
                      + ',@c_Sku             NVARCHAR(20)'
  

   INSERT INTO #TMP_VASActivity
      (  Orderkey           
      ,  OrderLineNumber   
      ,  Storerkey          
      ,  Sku               
      ,  Qty                
      ,  Activity 
      )          
   EXEC sp_executesql @c_SQL
         ,  @c_SQLArgument
         ,  @c_Loadkey                                         --(Wan01)
         ,  @c_Orderkey
         ,  @c_OrderLineNumber 
         ,  @c_Sku
                    
   QUIT_SP:

   SELECT Orderkey         = MAX(Orderkey)                     --(Wan02) 
      ,  OrderLineNumber   = MAX(OrderLineNumber)              --(Wan02)
      ,  Storerkey          
      ,  Sku               
      ,  Qty               = ISNULL(SUM(Qty),0)                --(Wan02)      
      ,  Activity
      ,  Checked
      ,  rowfocusindicatorcol = '    '
   FROM #TMP_VASActivity 
   GROUP BY Storerkey                                          --(Wan02)
         ,  Sku                                                --(Wan02)
         ,  Activity                                           --(Wan02)       
         ,  Checked                                            --(Wan02)
   ORDER BY Storerkey                                          --(Wan02)
         ,  Sku                                                --(Wan02)
         ,  Activity                                           --(Wan02)

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
  
END  

GO