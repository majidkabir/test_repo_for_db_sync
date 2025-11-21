SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/************************************************************************/        
/* Trigger: isp_EPreScanRFID01                                          */        
/* Creation Date: 13-OCT-2020                                           */        
/* Copyright: LF Logistics                                              */        
/* Written by: Wan                                                      */        
/*                                                                      */        
/* Purpose: WMS-15244 - [CN] NIKE_O2_Ecom_packing_RFID_CR               */        
/*        :                                                             */        
/* Called By: n_cst_packcarton_ecom                                     */        
/*          : of_getprescanrfidsp                                       */        
/*        :                                                             */        
/* PVCS Version: 1.3                                                    */        
/*                                                                      */        
/* Version: 7.0                                                         */        
/*                                                                      */        
/* Data Modifications:                                                  */        
/*                                                                      */        
/* Updates:                                                             */        
/* Date        Author   Ver   Purposes                                  */        
/* 13-OCT-2020 Wan      1.0   Created                                   */  
/* 11-MAY-2021 Wan01    1.1   WMS-17001 - [CN] NIKE_O2_Ecompacking_None */
/*                            RFID SKU Skip Validation_CR               */
/* 02-JUL-2021 ML01     1.2   WMS-17342 - [CN] NIKE CN ECOM Packing - CR*/
/* 16-Jan-2023 Wan02    1.3   WMS-21512 - [CN] NIKE_NFC_RFID_ECOMPACKING*/
/*                            _CR_V1.0                                  */
/*                            DevOps Combine Script                     */
/************************************************************************/        
CREATE   PROC [dbo].[isp_EPreScanRFID01]        
         @c_TaskBatchNo NVARCHAR(10)         
      ,  @c_PickSlipNo  NVARCHAR(10)       
      ,  @c_Storerkey   NVARCHAR(15) = ''        
      ,  @c_Sku         NVARCHAR(20) = ''    
      ,  @b_Success     INT = 0              OUTPUT          
      ,  @n_err         INT = 0              OUTPUT         
      ,  @c_errmsg      NVARCHAR(255) = ''   OUTPUT 
      ,  @c_Tag_Reader  NVARCHAR(10)  = ''   OUTPUT               --(Wan02)    
AS        
BEGIN        
   SET NOCOUNT ON        
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
        
   DECLARE @n_StartTCnt          INT         = @@TRANCOUNT         
         , @n_Continue           INT         = 1   

         , @c_ExtendedField03    NVARCHAR(30)= ''
          
   SET @b_Success  = 0        
   SET @n_err      = 0        
   SET @c_errmsg   = ''   
   
   --(ML01) - START
      IF NOT EXISTS (SELECT 1
                 FROM dbo.PackTask AS pt WITH (NOLOCK)
                 JOIN dbo.ORDERS AS o WITH (NOLOCK) ON o.orderkey = pt.orderkey
                 WHERE pt.TaskBatchNo = @c_TaskBatchNo
                 AND o.B_Company <> '3940'
                 )
                 
      BEGIN   
         GOTO QUIT_SP       
      END     
   --(ML01) - END
          
   
   --(Wan01) - START
   IF @c_Sku = ''
   BEGIN
      IF EXISTS (SELECT 1
                 FROM dbo.PackTask AS pt WITH (NOLOCK)
                 JOIN dbo.PICKDETAIL AS p WITH (NOLOCK)  ON pt.OrderKey = p.Orderkey
                 JOIN dbo.SkuInfo    AS si WITH (NOLOCK) ON  si.Storerkey = p.Storerkey
                                                         AND si.Sku = p.Sku
                 WHERE pt.TaskBatchNo = @c_TaskBatchNo
                 AND si.ExtendedField03 IN ( 'rfid', 'nfc' )               --(Wan02)
                 )
                 
      BEGIN
         SET @b_Success = 1         
      END
      
      GOTO QUIT_SP      
   END
   --(Wan01) - END
     
   SET @c_Tag_Reader = ''        
   SELECT @c_Tag_Reader = LOWER(SIF.ExtendedField03)        --(Wan02)         
   FROM SKUINFO SIF WITH (NOLOCK)        
   WHERE SIF.Storerkey = @c_Storerkey  
   AND   SIF.Sku = @c_Sku          
        
   IF @c_Tag_Reader IN ( 'rfid', 'nfc' )                    --(Wan02)      
   BEGIN          
     SET @b_Success = 1        
   END           
       
   QUIT_SP:        
         
END -- procedure 

GO