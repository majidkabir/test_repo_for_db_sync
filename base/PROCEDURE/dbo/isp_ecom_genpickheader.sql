SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Trigger: [dbo].[isp_ECOM_GenPickHeader]                              */  
/* Creation Date: 12-DEC-2023                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: Alex                                                     */  
/*                                                                      */  
/* Purpose: PAC-301 - New ECOM Packing                                  */  
/*          :                                                           */  
/* Called By:                                                           */  
/*          :                                                           */  
/* PVCS Version: 1.8                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date           Author      Purposes                                  */  
/************************************************************************/  
CREATE   PROC [dbo].[isp_ECOM_GenPickHeader]
   @c_OrderKey       NVARCHAR(10),
   @c_TempPickSlipNo NVARCHAR(10),
   @c_NewPickSlipNo  NVARCHAR(10),
   @b_success        INT = 1              OUTPUT,
   @n_err            INT = 0              OUTPUT,
   @c_errmsg         NVARCHAR(255) = ''   OUTPUT    
AS  
BEGIN  
   DECLARE @n_StartTCnt       INT = @@TRANCOUNT
         , @n_Continue        INT = 1
   
   SET @c_NewPickSlipNo       = ISNULL(RTRIM(@c_NewPickSlipNo), '')
   SET @c_TempPickSlipNo      = ISNULL(RTRIM(@c_TempPickSlipNo), '')
   SET @c_OrderKey            = ISNULL(RTRIM(@c_OrderKey), '')
   
   SET @b_success = 1
   SET @n_err     = 0
   SET @c_errmsg  = ''
   

   IF @c_OrderKey <> ''
   BEGIN
      --Insert PickHeader
      IF @c_TempPickSlipNo <> ''
         AND NOT EXISTS (SELECT 1 FROM [dbo].[PickHeader] WITH (NOLOCK) 
            WHERE [Orderkey] = @c_OrderKey AND [Zone] = '3')
      BEGIN
         -- Zone = 3 - discrete (orderkey, externorderkey), 7 - Consolidate (externorderkey), LP - Loadplan (Loadkey)  
         INSERT INTO PICKHEADER   
            (  PickHeaderKey  
            ,  Orderkey  
            ,  Storerkey  
            ,  ExternOrderkey  
            ,  Consigneekey  
            ,  Priority  
            ,  Type  
            ,  Zone  
            ,  Status  
            ,  PickType  
            ,  EffectiveDate  
            )  
         SELECT 
               CASE WHEN @c_NewPickSlipNo <> '' THEN @c_NewPickSlipNo ELSE @c_TempPickSlipNo END
            ,  Orderkey  
            ,  Storerkey  
            ,  Loadkey  
            ,  Consigneekey  
            ,  '5'  
            ,  '5'  
            ,  '3'  
            ,  '0'  
            ,  '0'  
            ,  GETDATE()  
         FROM ORDERS WITH (NOLOCK)  
         WHERE Orderkey = @c_Orderkey
         
         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @c_Errmsg = ERROR_MESSAGE()
         END
      END
      --Update PickHEADER
      ELSE IF @c_NewPickSlipNo <> '' AND @c_TempPickSlipNo <> ''
         AND EXISTS (SELECT 1 FROM [dbo].[PickHeader] WITH (NOLOCK) 
            WHERE [PickHeaderKey] = @c_TempPickSlipNo)
      BEGIN
         UPDATE PICKHEADER WITH (ROWLOCK)
         SET [PickHeaderKey] = @c_NewPickSlipNo
         WHERE [PickHeaderKey] = @c_TempPickSlipNo
         
         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @c_Errmsg = ERROR_MESSAGE()
         END
      END
   END
   
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_ECOM_GenPickHeader'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure  


GO