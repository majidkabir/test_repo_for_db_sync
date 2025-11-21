SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_AltPackInfo01                                       */
/* Creation Date: 2020-07-09                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-13806 - SG - NIKESGEC ¿C Carton Dimension from SKU       */
/*        :                                                             */
/* Called By: isp_PackCartonInfo_Wrapper                                */
/*          : SubSP isp_AltPackInfoXX                                   */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_AltPackInfo01]
         @c_PickSlipNo        NVARCHAR(10)  
      ,  @n_CartonNo          INT
      ,  @c_Storerkey         NVARCHAR(10) = ''
      ,  @c_Sku               NVARCHAR(20) = ''
      ,  @c_CallFrom          NVARCHAR(20) = ''
      ,  @c_CartonType        NVARCHAR(10) = '' OUTPUT
      ,  @n_Cube              FLOAT = 0.00      OUTPUT
      ,  @c_SkipCubeWgt       NVARCHAR(2)  ='0' OUTPUT
      ,  @n_Weight            FLOAT = 0.00      OUTPUT  
      ,  @b_Success           INT               OUTPUT   ---0: Fail, 1: Success, 2: Not Setup Storerconfig/Continue to get or create Standard CartonInfo   
      ,  @n_Err               INT               OUTPUT
      ,  @c_ErrMsg            NVARCHAR(255)     OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt          INT         = @@TRANCOUNT
         , @n_Continue           INT         = 1

         , @b_HIPPIE             BIT         = 0   
         , @n_OpenQty            INT         = 0
               
         , @c_Orderkey           NVARCHAR(10)= ''
         , @c_Loadkey            NVARCHAR(10)= ''

         , @c_Facility           NVARCHAR(5) = ''
         , @c_OrderGroup         NVARCHAR(10)= ''

         , @c_AltPackInfo        NVARCHAR(30)= ''
         , @c_CartonType_Hippie  NVARCHAR(60)= ''
         , @c_SkipCubeWgt_Hippie NVARCHAR(60)= ''

   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @n_Cube   = 0.00      
   SET @n_Weight = 0.00 
    
   SELECT TOP 1 @c_Orderkey = PH.Orderkey
               ,@c_Loadkey  = ISNULL(PH.ExternOrderkey,'')
   FROM PICKHEADER PH WITH (NOLOCK) 
   WHERE PH.PickHeaderKey = @c_PickSlipNo

   IF @c_Orderkey = ''
   BEGIN
      SELECT TOP 1 @c_Orderkey = LPD.Orderkey
      FROM LOADPLANDETAIL LPD WITH (NOLOCK)
      WHERE LPD.Loadkey = @c_Loadkey
      ORDER BY LPD.LoadLineNumber
   END

   SELECT   @c_Facility  = OH.Facility
         ,  @c_OrderGroup= OH.OrderGroup
         ,  @n_OpenQty   = OH.OpenQty
   FROM ORDERS OH WITH (NOLOCK) 
   WHERE OH.Orderkey = @c_Orderkey 

   IF @c_OrderGroup NOT IN ('SINGLE') --AND (@c_CallFrom <> 'GetCartonInfo' OR @c_CartonType = '')
   BEGIN 
      SET @b_Success = 2
      GOTO QUIT_SP
   END  

   IF @n_OpenQty > 1  -- Double Validation to check if multi orders
   BEGIN 
      SET @b_Success = 2
      GOTO QUIT_SP
   END  

   EXEC nspGetRight
         @c_Facility   = @c_Facility  
      ,  @c_StorerKey  = @c_StorerKey 
      ,  @c_sku        = ''       
      ,  @c_ConfigKey  = 'AltPackInfo' 
      ,  @b_Success    = @b_Success             OUTPUT
      ,  @c_authority  = @c_AltPackInfo         OUTPUT 
      ,  @n_err        = @n_err                 OUTPUT
      ,  @c_errmsg     = @c_errmsg              OUTPUT
      ,  @c_Option2    = @c_CartonType_Hippie   OUTPUT
      ,  @c_Option3    = @c_SkipCubeWgt_Hippie  OUTPUT

   SET @c_CartonType_Hippie = ISNULL(@c_CartonType_Hippie,'')

   IF @c_AltPackInfo = '0'    -- Not Turn On
   BEGIN
      SET @b_Success = 2
      GOTO QUIT_SP
   END  

   IF @c_CallFrom = 'PackInfoCheckReq'
   BEGIN
      IF @c_CartonType_Hippie = @c_CartonType
      BEGIN
         SET @c_SkipCubeWgt = @c_SkipCubeWgt_Hippie -- PackInfo is mandatory for Cube & Weight
         SET @b_Success = 1
      END
      ELSE
      BEGIN
         SET @b_Success = 2
      END
      GOTO QUIT_SP
   END

   IF @c_CallFrom IN ( 'ESingleGetPackInfo', 'GetPackInfo')
   BEGIN
      IF @c_CallFrom = 'GetPackInfo'
      BEGIN
         SELECT @c_Sku = MIN(PD.Sku)
         FROM PACKDETAIL PD WITH (NOLOCK)
         WHERE PD.PickSlipNo = @c_PickSlipNo
         GROUP BY PD.PickSlipNo
         HAVING SUM(PD.Qty) = 1 AND COUNT(DISTINCT PD.Sku) = 1
      END
       -- Default Hippie Carton info
      SET @b_HIPPIE = 0
      SELECT @n_Cube =  ISNULL(SKU.[Length],0.00) * ISNULL(SKU.[Width],0.00) * ISNULL(SKU.[Height],0.00)
            ,@b_HIPPIE = 1
      FROM SKU SKU WITH (NOLOCK)
      WHERE SKU.Storerkey  = @c_Storerkey
      AND SKU.Sku          = @c_Sku
      AND SKU.ProductModel = 'HIPPIE'

      SET @c_SkipCubeWgt = @c_SkipCubeWgt_Hippie -- PackInfo is mandatory for Cube & Weight

      SET @b_Success = 1
      IF @c_CartonType <> '' 
      BEGIN
         IF @b_HIPPIE = 0 AND @c_CartonType <> @c_CartonType_Hippie
         BEGIN
            SET @b_Success = 2
            GOTO QUIT_SP
         END
         ELSE IF @b_HIPPIE = 1 AND @c_CartonType = @c_CartonType_Hippie
         BEGIN
            SET @b_Success = 1
            GOTO QUIT_SP
         END
         ELSE IF @b_HIPPIE = 1
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 70210   
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Invalid CartonType for Single Hippie Product. (isp_AltPackInfo01)'   
            GOTO QUIT_SP 
         END 
         ELSE IF @b_HIPPIE = 0
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 70220  
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Invalid Hippie CartonType for Non Single Hippie Product. (isp_AltPackInfo01)'   
            GOTO QUIT_SP 
         END 
      END
      ELSE IF @c_CartonType = ''                    -- 1) Open PackInfo -- Add Custom CartonType to DropDown 2) Default Cube & Weight if Hippie product
      BEGIN
         IF @b_HIPPIE = 1                           -- 2020-09-09 Fixed: Non Hippie Show Hippie on CartonType
         BEGIN                                       
            SET @c_CartonType = ISNULL(@c_CartonType_Hippie,'')  -- 2020-09-04 Fixed: Non Hippie Show Hippie on CartonType
         END 
         ELSE
         BEGIN
            SET @n_Cube = 0.0
         END                                       -- 2020-09-09 Fixed: Non Hippie Show Hippie on CartonType
         GOTO QUIT_SP
      END
   END 

   IF @c_CallFrom = 'CapturePackInfo'
   BEGIN
      SET @b_Success = 1
      SET @c_CartonType = @c_CartonType_Hippie

      INSERT INTO PACKINFO (PickSlipNo, CartonNo, Qty, CartonType, [Cube], [Weight], [Length], Width, Height) 
      SELECT PD.PickSlipNo
            ,PD.CartonNo
            ,Qty      = SUM(PD.Qty)
            ,CartonType = @c_CartonType
            ,[Cube]   = SUM(PD.Qty) * (ISNULL(SKU.[Length],0.00) * ISNULL(SKU.[Width],0.00) * ISNULL(SKU.[Height],0.00))
            ,[Weight] = 0
            ,[Length] = ISNULL(SKU.[Length],0.00)
            ,Width    = ISNULL(SKU.[Width],0.00)
            ,Height   = ISNULL(SKU.[Height],0.00)
      FROM PACKDETAIL PD  WITH (NOLOCK)
      LEFT OUTER JOIN PACKINFO   PIF WITH (NOLOCK) ON PD.PickSlipNo = PIF.PickSlipNo
                                                  AND PD.CartonNo   = PIF.CartonNo
      JOIN SKU SKU WITH (NOLOCK) ON PD.StorerKey = SKU.StorerKey
                                 AND PD.Sku = SKU.Sku
      WHERE PD.PickSlipNo  = @c_PickSlipNo 
      AND SKU.ProductModel = 'HIPPIE'
      AND PIF.PickSlipNo IS NULL
      GROUP BY PD.PickSlipNo
            ,  PD.CartonNo
            ,  PD.Sku
            ,  ISNULL(SKU.[Length],0.00)
            ,  ISNULL(SKU.[Width],0.00)
            ,  ISNULL(SKU.[Height],0.00)
      HAVING COUNT(DISTINCT PD.Sku) = 1 AND SUM(PD.Qty) = 1

      IF EXISTS ( SELECT 1
                  FROM PACKDETAIL PD  WITH (NOLOCK)
                  LEFT OUTER JOIN PACKINFO PIF WITH (NOLOCK) ON PD.PickSlipNo = PIF.PickSlipNo
                                                            AND PD.CartonNo   = PIF.CartonNo
                  JOIN SKU SKU WITH (NOLOCK) ON PD.StorerKey = SKU.StorerKey
                                             AND PD.Sku = SKU.Sku
                  WHERE PD.PickSlipNo  = @c_PickSlipNo 
                  AND PIF.PickSlipNo IS NULL
               )
      BEGIN 
         SET @b_Success = 2
      END
   END
 
QUIT_SP:
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_PackCartonInfo_Wrapper'
     -- RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      --SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

END -- procedure

GO