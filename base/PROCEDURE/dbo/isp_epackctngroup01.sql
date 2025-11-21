SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/************************************************************************/        
/* Trigger: isp_EPackCTNGroup01                                         */        
/* Creation Date: 14-DEC-2020                                           */        
/* Copyright: LF Logistics                                              */        
/* Written by: Wan                                                      */        
/*                                                                      */        
/* Purpose: WMS-15244 - [CN] NIKE_O2_Ecom_packing_RFID_CR               */        
/*        :                                                             */        
/* Called By: n_cst_packcarton_ecom                                     */        
/*          : of_getprescanrfidsp                                       */        
/*        :                                                             */        
/* PVCS Version: 1.0                                                    */        
/*                                                                      */        
/* Version: 7.0                                                         */        
/*                                                                      */        
/* Data Modifications:                                                  */        
/*                                                                      */        
/* Updates:                                                             */        
/* Date        Author   Ver   Purposes                                  */        
/* 14-DEC-2020 Wan      1.0   Created                                   */         
/************************************************************************/        
CREATE PROC [dbo].[isp_EPackCTNGroup01]        
         @c_Facility       NVARCHAR(5)                                    
      ,  @c_CartonType     NVARCHAR(10)    
      ,  @c_PickSlipNo     NVARCHAR(10)  
      ,  @n_CartonNo       INT
      ,  @c_CartonGroupALT NVARCHAR(10)         OUTPUT
      ,  @c_Alertmsg       NVARCHAR(255) = ''   OUTPUT         
AS        
BEGIN        
   SET NOCOUNT ON        
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
        
   DECLARE @n_StartTCnt       INT         = @@TRANCOUNT         
         , @n_Continue        INT         = 1 
         
         , @c_TaskBatchNo     NVARCHAR(10)= ''
         , @c_OrderMode       NVARCHAR(10)= ''
         
         , @c_SkuCartonType   NVARCHAR(10)= '' 
         , @c_Storerkey       NVARCHAR(15)= ''
         , @c_Sku             NVARCHAR(20)= '' 
  
   SET @c_Alertmsg = ''              
   SET @c_CartonType = ISNULL(@c_CartonType,'')        
          
   IF ISNULL(@c_PickSlipNo,'') = '' OR ISNULL(@n_CartonNo,0) = 0
   BEGIN
   	GOTO QUIT_SP
   END
   
   SELECT  @c_TaskBatchNo = PH.TaskBatchNo
   FROM PACKHEADER PH WITH (NOLOCK)
   WHERE PH.PickSlipNo = @c_PickSlipNo
   
   SELECT TOP 1 @c_OrderMode = PT.OrderMode
   FROM PackTask AS pt WITH (NOLOCK)
   WHERE pt.TaskBatchNo = @c_TaskBatchNo
 
   IF @c_OrderMode LIKE 'M%' 
   BEGIN
   	GOTO QUIT_SP
   END 

   SELECT  @c_Storerkey = PD.Storerkey
         , @c_Sku = PD.SKU
   FROM PACKDETAIL PD WITH (NOLOCK)
   WHERE PD.PickSlipNo = @c_PickSlipNo
   AND PD.CartonNo = @n_CartonNo
          
   SELECT @c_CartonGroupALT = SKU.CartonGroup        
   FROM SKU WITH (NOLOCK)        
   WHERE SKU.Storerkey = @c_Storerkey  
   AND   SKU.Sku = @c_Sku   
   
   SELECT TOP 1 @c_SkuCartonType = CZ.CartonType
   FROM CARTONIZATION CZ WITH (NOLOCK)  
   WHERE CZ.CartonizationGroup = @c_CartonGroupALT
   ORDER BY CZ.UseSequence    
        
   IF @c_CartonType <> '' AND @c_SkuCartonType <> '' AND @c_CartonType <> @c_SkuCartonType
   BEGIN
      SET @c_AlertMsg = 'Warning: Carton Type: ' + @c_CartonType + ' is diference from Sku Carton Type: ' + @c_SkuCartonType
   END
        
   QUIT_SP:        
         
END -- procedure 

GO