SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: ispGETSKU01                                        */  
/* Creation Date: 23/03/2022                                            */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-19279 CN Loreal Ecom packing get sku by UPC by order or */ 
/*          taskbatch                                                   */
/*                                                                      */  
/* Called By: isp_GetPackSku_Wrapper (storerconfig:GetPackSku_SP)       */  
/*                                                                      */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */  
/* 23-MAR-2022 NJOW     1.0   DEVOPS combine scirpt                     */
/************************************************************************/   

CREATE PROCEDURE [dbo].[ispGETSKU01]
     @c_TaskBatchNo  NVARCHAR(10)=''
   , @c_PickslipNo   NVARCHAR(10)=''
   , @c_OrderKey     NVARCHAR(10)=''
   , @c_Storerkey    NVARCHAR(15)
   , @c_Sku          NVARCHAR(60)
   , @c_NewSku       NVARCHAR(30)  OUTPUT     
   , @b_Success      INT           OUTPUT
   , @n_Err          INT           OUTPUT 
   , @c_ErrMsg       NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_Continue     INT = 1 
         , @n_StartTcnt    INT = @@TRANCOUNT   
         , @c_TempSku      NVARCHAR(20) = ''
         , @n_Noofsku      INT = 0    

   SELECT @b_success = 1, @n_err = 0, @c_errmsg = ''

   IF ISNULL(@c_Orderkey,'') <> ''
   BEGIN   	  
      SELECT @c_TempSku = MIN(s.Sku), 
             @n_Noofsku = COUNT(DISTINCT s.Sku) 
      FROM ORDERDETAIL OD (NOLOCK)
      JOIN SKU AS s WITH(NOLOCK) ON s.StorerKey = OD.StorerKey AND s.Sku = OD.SKU
      WHERE OD.Orderkey = @c_Orderkey
      AND s.StorerKey = @c_StorerKey 
      AND s.Altsku = @c_SKU     
      GROUP BY s.Altsku

   	  IF ISNULL(@c_TempSku,'') = ''
   	  BEGIN
         SELECT @c_TempSku = MIN(s.Sku), 
                @n_Noofsku = COUNT(DISTINCT s.Sku) 
         FROM ORDERDETAIL OD (NOLOCK)
         JOIN SKU AS s WITH(NOLOCK) ON s.StorerKey = OD.StorerKey AND s.Sku = OD.SKU
         WHERE OD.Orderkey = @c_Orderkey
         AND s.StorerKey = @c_StorerKey 
         AND s.ManuFacturerSku = @c_SKU     
         GROUP BY s.ManuFacturerSku
   	  END

   	  IF ISNULL(@c_TempSku,'') = ''
   	  BEGIN
         SELECT @c_TempSku = MIN(s.Sku), 
                @n_Noofsku = COUNT(DISTINCT s.Sku) 
         FROM ORDERDETAIL OD (NOLOCK)
         JOIN SKU AS s WITH(NOLOCK) ON s.StorerKey = OD.StorerKey AND s.Sku = OD.SKU
         WHERE OD.Orderkey = @c_Orderkey
         AND s.StorerKey = @c_StorerKey 
         AND s.RetailSku = @c_SKU     
         GROUP BY s.RetailSku
   	  END

   	  IF ISNULL(@c_TempSku,'') = ''
   	  BEGIN
         SELECT @c_TempSku = MIN(s.Sku), 
                @n_Noofsku = COUNT(DISTINCT UPC.Sku) 
         FROM ORDERDETAIL OD (NOLOCK)
         JOIN UPC (NOLOCK) ON  OD.Storerkey = UPC.Storerkey AND OD.Sku = UPC.Sku
         JOIN SKU AS s WITH(NOLOCK) ON s.StorerKey = UPC.StorerKey AND s.Sku = UPC.SKU
         WHERE OD.Orderkey = @c_Orderkey
         AND UPC.StorerKey = @c_StorerKey 
         AND UPC.UPC = @c_SKU     
         GROUP BY UPC.UPC      
      END
   END   
   ELSE IF ISNULL(@c_TaskBatchNo,'') <> ''
   BEGIN
   	  SELECT @c_TempSku = MIN(s.Sku), 
   	         @n_Noofsku = COUNT(DISTINCT s.Sku) 
   	  FROM PACKTASK PT (NOLOCK)
   	  JOIN PACKTASKDETAIL PTD (NOLOCK) ON PT.TaskBatchNo = PTD.TaskBatchNo AND PT.Orderkey = PTD.Orderkey
      JOIN SKU AS s WITH(NOLOCK) ON s.StorerKey = PTD.StorerKey AND s.Sku = PTD.SKU
      WHERE PT.TaskBatchNo = @c_TaskBatchNo
   	  AND s.AltSku = @c_Sku
   	  AND PTD.QtyAllocated > PTD.QtyPacked
   	  GROUP BY s.AltSku

   	  IF ISNULL(@c_TempSku,'') = ''
   	  BEGIN
   	     SELECT @c_TempSku = MIN(s.Sku), 
   	            @n_Noofsku = COUNT(DISTINCT s.Sku) 
   	     FROM PACKTASK PT (NOLOCK)
   	     JOIN PACKTASKDETAIL PTD (NOLOCK) ON PT.TaskBatchNo = PTD.TaskBatchNo AND PT.Orderkey = PTD.Orderkey
         JOIN SKU AS s WITH(NOLOCK) ON s.StorerKey = PTD.StorerKey AND s.Sku = PTD.SKU          
   	     WHERE PT.TaskBatchNo = @c_TaskBatchNo
   	     AND s.ManuFacturerSku = @c_Sku
      	 AND PTD.QtyAllocated > PTD.QtyPacked
   	     GROUP BY s.ManuFacturerSku
   	  END   	  

   	  IF ISNULL(@c_TempSku,'') = ''
   	  BEGIN
   	     SELECT @c_TempSku = MIN(s.Sku), 
   	            @n_Noofsku = COUNT(DISTINCT s.Sku) 
   	     FROM PACKTASK PT (NOLOCK)
   	     JOIN PACKTASKDETAIL PTD (NOLOCK) ON PT.TaskBatchNo = PTD.TaskBatchNo AND PT.Orderkey = PTD.Orderkey
         JOIN SKU AS s WITH(NOLOCK) ON s.StorerKey = PTD.StorerKey AND s.Sku = PTD.SKU          
   	     WHERE PT.TaskBatchNo = @c_TaskBatchNo
   	     AND s.RetailSku = @c_Sku
      	 AND PTD.QtyAllocated > PTD.QtyPacked
   	     GROUP BY s.RetailSku
   	  END   	  

   	  IF ISNULL(@c_TempSku,'') = ''
   	  BEGIN
   	     SELECT @c_TempSku = MIN(s.Sku), 
   	            @n_Noofsku = COUNT(DISTINCT UPC.Sku) 
   	     FROM PACKTASK PT (NOLOCK)
   	     JOIN PACKTASKDETAIL PTD (NOLOCK) ON PT.TaskBatchNo = PTD.TaskBatchNo AND PT.Orderkey = PTD.Orderkey
         JOIN UPC (NOLOCK) ON  PTD.Storerkey = UPC.Storerkey AND PTD.Sku = UPC.Sku
         JOIN SKU AS s WITH(NOLOCK) ON s.StorerKey = UPC.StorerKey AND s.Sku = UPC.SKU         
   	     WHERE PT.TaskBatchNo = @c_TaskBatchNo
   	     AND UPC.UPC = @c_Sku
      	 AND PTD.QtyAllocated > PTD.QtyPacked
   	     GROUP BY UPC.UPC     	   
   	  END     
   END
   
   IF ISNULL(@c_TempSku,'') <> ''
   BEGIN
      IF ISNULL(@n_Noofsku,0) >= 2
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 83010
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Found more than one Sku of UPC ' + RTRIM(ISNULL(@c_Sku,'')) + ' (ispGETSKU01)'      	
      END
      ELSE
      BEGIN
      	 SET @c_NewSku = @c_TempSku
      END
   END   

QUIT_SP:     

   IF @n_Continue=3  -- Error Occured - Process AND Return
   BEGIN
      SET @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispGETSKU01'    
      RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END  
END -- End Procedure

GO