SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Function: fnc_ECOM_GetPackOrderStatus                                */
/* Creation Date: 23-SEP-2016                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Shong/YTWan                                              */
/*                                                                      */
/* Purpose: SOS#361901 - New ECOM Packing                               */
/*        :                                                             */
/* Called By: isp_Ecom_GetPackTaskOrders_M                              */
/*          : isp_Ecom_QueryRules                                       */
/*          : isp_Ecom_GetValidQtyPacked                                */
/*                                                                      */
/* PVCS Version: 1.4                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 21-Jul-2017 Shong    1.1  Performance Tuning                         */
/* 02-Oct-2017 Wan01    1.2  Performance Tuning                         */
/* 28-AUG-2017 Wan02    1.3  Performance Tuning                         */
/* 04-MAR-2021 Wan03    1.4  WMS-16390 - [CN] NIKE_O2_Ecompacking_Check */
/*                           _Pickdetail_status_CR                      */
/************************************************************************/
CREATE FUNCTION [dbo].[fnc_ECOM_GetPackOrderStatus] 
  ( 
    @c_TaskBatchNo NVARCHAR(10),
    @c_PickSlipNo  NVARCHAR(10), 
    @c_OrderKey    NVARCHAR(10)
  )
RETURNS NVARCHAR(2)
AS
BEGIN 
   DECLARE @c_PH_OrderKey NVARCHAR(10), 
           @c_PH_Status   NVARCHAR(1), 
           @c_OH_Status   NVARCHAR(1), 
           @c_RT_Status   NVARCHAR(1),
           --@c_PackSKU     NVARCHAR(20), 
           @c_PTaskSKU    NVARCHAR(20), 
           @n_PackQty     INT, 
           @n_PTaskQty    INT 

         , @c_NonePackStatus  NVARCHAR(30)   --(Wan01)
         , @c_SOStatus        NVARCHAR(10)   --(Wan01)    
         , @c_ORDStatus       NVARCHAR(10)   --(Wan01)    
         , @c_Storerkey       NVARCHAR(15)   --(Wan01)
        
   SET @c_PH_OrderKey = ''
   SET @c_PH_Status = ''
   SET @c_RT_Status = '0'
   
   IF ISNULL(RTRIM(@c_PickSlipNo),'') <> ''
   BEGIN
      SELECT @c_PH_OrderKey = OrderKey, 
             @c_PH_Status   = [Status] 
      FROM PACKHEADER WITH (NOLOCK)
      WHERE PickSlipNo = @c_PickSlipNo 
   END

   IF ISNULL(RTRIM(@c_PickSlipNo),'') = '' AND @c_OrderKey <> ''
   BEGIN
      SELECT @c_PH_OrderKey = OrderKey, 
             @c_PH_Status   = [Status] 
      FROM PACKHEADER WITH (NOLOCK)
      WHERE Orderkey = @c_OrderKey 
   END

   IF @c_PH_OrderKey = @c_OrderKey 
   BEGIN
      IF @c_PH_Status <> '9'
         SET @c_RT_Status = '3'
      ELSE 
         SET @c_RT_Status = '9'
   
      GOTO EXIT_FNC 
   END

   --(Wan02) - START
   SET @c_SOStatus  = ''
   SET @c_ORDStatus = ''
   SET @c_Storerkey = ''

   SELECT @c_SOStatus = OH.SOStatus
       ,  @c_ORDStatus= OH.[Status]
       ,  @c_Storerkey= OH.Storerkey
   FROM ORDERS OH WITH (NOLOCK) 
   WHERE  OrderKey = @c_OrderKey 

   SET @c_NonePackStatus = ''
   IF @c_SOStatus NOT IN ('CANC', 'HOLD')
   BEGIN
      IF EXISTS ( SELECT 1   
                  FROM CODELKUP CL WITH (NOLOCK)  
                  WHERE CL.ListName = 'NONEPACKSO'
                  AND   CL.Storerkey= @c_Storerkey
                )
      BEGIN 
         SELECT TOP 1 @c_NonePackStatus = CL.Code
         FROM CODELKUP CL WITH (NOLOCK)  
         WHERE CL.ListName = 'NONEPACKSO'
         AND   CL.Code     = @c_SOStatus 
         AND   CL.Storerkey= @c_Storerkey
      END
      ELSE
      BEGIN
         SELECT TOP 1 @c_NonePackStatus = CL.Code
         FROM CODELKUP CL WITH (NOLOCK)  
         WHERE CL.ListName = 'NONEPACKSO'
         AND   CL.Code     = @c_SOStatus 
         AND   CL.Storerkey= ''
      END
   END

   SET @c_OH_Status = CASE WHEN @c_SOStatus IN ('CANC', 'HOLD') THEN 'X'
                           WHEN @c_SOStatus = @c_NonePackStatus THEN 'X'
                           WHEN @c_ORDStatus  >= '5' THEN '9'
                           ELSE '0' 
                           END 
   --(Wan02) - END

   IF @c_OH_Status IN ('X', '9')
   BEGIN
      SET @c_RT_Status = @c_OH_Status 
      GOTO EXIT_FNC     
   END

   IF @c_PH_Status = '9'
   BEGIN
      SET @c_RT_Status = '0'
      GOTO EXIT_FNC 
   END
   
   --(Wan01) - START
   DECLARE @n_MatchedSKU   BIT 

         , @c_SKU          NVARCHAR(20)
         , @c_PackSKU      NVARCHAR(20)
         , @c_PickSKU      NVARCHAR(20)
         , @c_Type         NVARCHAR(10)

         , @n_Qty          INT
         , @n_QtyPack      INT
         , @n_QtyPick      INT
         , @n_QtyTotalPack INT
         , @n_QtyTotalPick INT

   DECLARE @cur_MatchSku CURSOR  
           
   SET @n_MatchedSKU = 1 

   SET @n_QtyTotalPack = 0
   SET @n_QtyTotalPick = 0
   SET @cur_MatchSku = CURSOR FAST_FORWARD READ_ONLY FOR      
      SELECT [Sku] = PTD.SKU, [Type] = 'PICK', [Qty] = SUM(PTD.QtyAllocated) 
      FROM PACKTASKDETAIL AS PTD WITH (NOLOCK)
      WHERE PTD.TaskBatchNo = @c_TaskBatchNo
      AND PTD.Orderkey = @c_OrderKey
      AND PTD.[Status] NOT IN ('P','X','9')        --(Wan03)
      GROUP BY PTD.SKU

      UNION ALL

      SELECT [Sku] = PD.SKU, [Type] = 'PACK', [Qty] = SUM(PD.Qty) 
      FROM PACKDETAIL PD WITH (NOLOCK) 
      WHERE PD.PickSlipNo = @c_PickSlipNo
      GROUP BY PD.SKU  
      ORDER BY Sku
            ,  [Type]   
   OPEN @cur_MatchSku

   FETCH NEXT FROM @cur_MatchSku INTO @c_Sku, @c_Type, @n_Qty 
   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @n_QtyPack = 0

      IF @c_Type = 'PICK'
      BEGIN
         SET @n_QtyPick = @n_Qty
         GOTO NEXT_REC
      END

      SET @c_PackSku = @c_Sku
      SET @n_QtyPack = @n_Qty

      FETCH NEXT FROM @cur_MatchSku INTO @c_Sku, @c_Type, @n_Qty 

      SET @c_PickSku = @c_Sku
      SET @n_QtyPick = @n_Qty
   
      IF @c_Type = 'PACK' OR @@FETCH_STATUS = -1
      BEGIN
         SET @c_PickSku = ''
      END
   
      IF @c_PackSku <> @c_PickSku  
      BEGIN
         SET @n_MatchedSKU = 0 
         BREAK
      END

      IF @n_QtyPack > @n_QtyPick
      BEGIN
         SET @n_MatchedSKU = 0 
         BREAK
      END

      NEXT_REC:
      SET @n_QtyTotalPack = @n_QtyTotalPack + @n_QtyPack
      SET @n_QtyTotalPick = @n_QtyTotalPick + @n_QtyPick

      FETCH NEXT FROM @cur_MatchSku INTO @c_Sku, @c_Type, @n_Qty 
   END

   SET @c_RT_Status = '0'

   IF @n_MatchedSKU = 1 AND @n_QtyTotalPack > 0 AND  @n_QtyTotalPack < @n_QtyTotalPick
   BEGIN
      SET @c_RT_Status = '1'
   END

   IF @n_MatchedSKU = 1 AND @n_QtyTotalPack > 0 AND @n_QtyTotalPack = @n_QtyTotalPick
   BEGIN
      SET @c_RT_Status = '2'
   END
   --(Wan01) - END
   EXIT_FNC:

   RETURN @c_RT_Status
END

GO