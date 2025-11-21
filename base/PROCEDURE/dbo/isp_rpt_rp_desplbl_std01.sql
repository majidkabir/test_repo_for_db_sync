SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_RPT_RP_DespLBL_Std01                                */
/* Creation Date: 2022-03-04                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: LFWM-3391 - MY-Convert Despatch Label to SCE                */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2022-03-04  Wan      1.0   Created & DevOps Combine Script           */
/************************************************************************/
CREATE   PROC [dbo].[isp_RPT_RP_DespLBL_Std01]
     @c_Orderkey           NVARCHAR(10)   = ''  OUTPUT  
   , @c_ExternOrderkey     NVARCHAR(30)   = ''
   , @c_PickSlipNo         NVARCHAR(30)   = ''
   , @n_PrintFrom          INT            = 1
   , @n_PrintTo            INT            = 1
   , @c_LabelType          CHAR(1)        = 'C' 
   , @n_NoOfLabel          INT            = 0   OUTPUT
   , @b_Success            INT            = 1   OUTPUT  
   , @c_ErrMsg             NVARCHAR(255)  = ''  OUTPUT           
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt                INT   = @@TRANCOUNT
         , @n_Continue                 INT   = 1  
         , @n_Err                      INT   = 0              
         , @n_NoOfCase                 INT   = 0
         , @n_NoOfPallet               INT   = 0
         
         , @c_Facility                 NVARCHAR(5) = ''
         , @c_Storerkey                NVARCHAR(15)= ''
         , @c_Status_ORD               NVARCHAR(10)= ''
         
         , @c_AllowPrintLBLB4ScanOut   NVARCHAR(30)   = ''

   SET @c_Orderkey         = ISNULL(@c_Orderkey      ,'') 
   SET @c_ExternOrderkey   = ISNULL(@c_ExternOrderkey,'')
   SET @c_PickSlipNo       = ISNULL(@c_PickSlipNo    ,'')      
   SET @n_PrintFrom        = ISNULL(@n_PrintFrom     ,0 )
   SET @n_PrintTo          = ISNULL(@n_PrintTo       ,0 )
   SET @c_LabelType        = IIF(@c_LabelType IS NULL OR @c_LabelType = '','C', @c_LabelType) 
   SET @b_Success          = 1     
   SET @c_ErrMsg           = ''    

   IF @c_Orderkey <> ''
   BEGIN
      SELECT TOP 1 @n_NoOfCase = o.ContainerQty
               , @n_NoOfPallet = o.BilledContainerQty  
               , @c_Facility   = o.Facility
               , @c_Storerkey  = o.StorerKey
               , @c_Status_ORD = o.[Status]           
      FROM dbo.ORDERS AS o WITH (NOLOCK)
      WHERE o.OrderKey = @c_Orderkey
      ORDER BY o.OrderKey
   END
   
   IF @c_Orderkey = '' AND @c_ExternOrderkey <> ''
   BEGIN
      SELECT TOP 1 
                 @n_NoOfCase   = o.ContainerQty
               , @n_NoOfPallet = o.BilledContainerQty 
               , @c_Orderkey   = o.OrderKey        
               , @c_Facility   = o.Facility
               , @c_Storerkey  = o.StorerKey
               , @c_Status_ORD = o.[Status]                                  
      FROM dbo.ORDERS AS o WITH (NOLOCK)
      WHERE o.ExternOrderKey = @c_ExternOrderkey
      ORDER BY o.OrderKey
   END
   
   IF @c_Orderkey = '' AND @c_PickSlipNo <> ''
   BEGIN
      SELECT TOP 1 
                 @n_NoOfCase   = o.ContainerQty
               , @n_NoOfPallet = o.BilledContainerQty
               , @c_Orderkey   = o.OrderKey
               , @c_Facility   = o.Facility
               , @c_Storerkey  = o.StorerKey
               , @c_Status_ORD = o.[Status]                       
      FROM dbo.PICKHEADER AS p WITH (NOLOCK)
      JOIN dbo.ORDERS AS o WITH (NOLOCK) ON o.OrderKey = p.OrderKey
      WHERE p.PickHeaderKey = @c_PickSlipNo
      ORDER BY p.OrderKey
   END
   
   IF @c_Orderkey = ''
   BEGIN
      SET @n_Continue = 3
      SET @c_Errmsg = 'Order# not found'
      GOTO QUIT_SP
   END
   
   SELECT @c_AllowPrintLBLB4ScanOut = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'AllowPrintLBLB4ScanOut')
   
   IF @c_AllowPrintLBLB4ScanOut IN ('','0') AND @c_Status_ORD < '5'
   BEGIN
      SET @n_Continue = 3
      SET @c_Errmsg = 'Order has not scanned out'
      GOTO QUIT_SP
   END 
   
   SET @n_NoOfLabel = IIF ( @c_LabelType = 'C', @n_NoOFCase, @n_NoOfPallet)
   IF @n_PrintTo > @n_NoOfLabel AND @n_NoOfLabel > 0
   BEGIN
      SET @n_Continue = 3     
      SET @c_Errmsg = 'Print To > Total ' + IIF ( @c_LabelType = 'C', 'Cartons', 'Pallets')
      GOTO QUIT_SP
   END
 
   IF @n_PrintFrom <= 0 OR @n_PrintTo <= 0 OR @n_PrintTo - @n_PrintFrom < 0
   BEGIN
      SET @n_Continue = 3
      SET @c_Errmsg = 'Invalid Print Range'
      GOTO QUIT_SP
   END
   
   SET @n_NoOfLabel =  @n_PrintTo - @n_PrintFrom + 1  
   
QUIT_SP:
   IF @n_Continue = 3
   BEGIN
      SET @b_Success = 0
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      SET @c_ErrMsg = ''
   END

END -- procedure

GO