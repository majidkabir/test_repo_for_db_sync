SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_AltPackInfo_Wrapper                                 */
/* Creation Date: 2020-07-09                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-13806 - SG - NIKESGEC ¿C Carton Dimension from SKU       */
/*        :                                                             */
/* Called By: Normal Packing - Capture PackInfo Screen                  */
/*          : of_CreatePackinfo (isp_CreatePackInfo) / w_popup_packinfo */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_AltPackInfo_Wrapper]
         @c_PickSlipNo        NVARCHAR(10)  
      ,  @n_CartonNo          INT
      ,  @c_Storerkey         NVARCHAR(10) = ''
      ,  @c_Sku               NVARCHAR(20) = ''
      ,  @c_CallFrom          NVARCHAR(20) = ''
      ,  @c_CartonType        NVARCHAR(10) = '' OUTPUT
      ,  @n_Cube              FLOAT = 0.00      OUTPUT
      ,  @n_Weight            FLOAT = 0.00      OUTPUT 
      ,  @c_SkipCubeWgt       NVARCHAR(2)  = '0'OUTPUT   --'0' or '':No Skip Any, 1:skip all, 2:Skip Cube only, 3:Skip Wgt Only
      ,  @b_Success           INT               OUTPUT   --0: Fail, 1: Success, 2: Not Setup Storerconfig/Continue to get or create Standard CartonInfo
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

         , @c_Orderkey           NVARCHAR(10)= ''
         , @c_Loadkey            NVARCHAR(10)= ''

         , @c_Facility           NVARCHAR(5) = ''

         , @c_AltPackInfo        NVARCHAR(30)= ''
         , @c_AltPackInfo_SP     NVARCHAR(50)= ''
         , @c_AltPIFCTNType      NVARCHAR(50)= ''
         
         , @c_SQL                NVARCHAR(1000)= ''
         , @c_SQLParms           NVARCHAR(1000)= ''

   SET @b_Success  = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

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

   SELECT @c_Facility  = OH.Facility
   FROM ORDERS OH WITH (NOLOCK) 
   WHERE OH.Orderkey = @c_Orderkey 

   EXEC nspGetRight
         @c_Facility   = @c_Facility  
      ,  @c_StorerKey  = @c_StorerKey 
      ,  @c_sku        = ''       
      ,  @c_ConfigKey  = 'AltPackInfo' 
      ,  @b_Success    = @b_Success             OUTPUT
      ,  @c_authority  = @c_AltPackInfo         OUTPUT 
      ,  @n_err        = @n_err                 OUTPUT
      ,  @c_errmsg     = @c_errmsg              OUTPUT
      ,  @c_Option1    = @c_AltPackInfo_SP      OUTPUT
      ,  @c_Option2    = @c_AltPIFCTNType       OUTPUT
      ,  @c_Option3    = @c_SkipCubeWgt         OUTPUT

   IF @b_Success = 0 
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 70110   
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing nspGetRight. (isp_AltPackInfo_Wrapper)'   
                  + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
      GOTO QUIT_SP  
   END

   SET @c_AltPackInfo_SP= ISNULL(@c_AltPackInfo_SP,'')
   SET @c_AltPIFCTNType = ISNULL(@c_AltPIFCTNType,'')
   SET @c_SkipCubeWgt   = ISNULL(@c_SkipCubeWgt,'')

   IF @c_AltPackInfo = 0
   BEGIN
      SET @b_Success = 2
      GOTO QUIT_SP
   END

   IF @c_AltPackInfo_SP = '' AND @c_AltPIFCTNType = ''
   BEGIN
      SET @b_Success = 2
      GOTO QUIT_SP
   END

   IF @c_SkipCubeWgt = '' 
   BEGIN
      SET @c_SkipCubeWgt = '0'
   END

   IF @c_AltPackInfo_SP = '' AND @c_AltPIFCTNType <> ''   
   BEGIN
      IF @c_CartonType = '' 
      BEGIN
         SET @c_CartonType = @c_AltPIFCTNType --Set Default Alt CartonType

         IF @c_CallFrom NOT IN ('GetPackInfo', 'PackInfoCheckReq')
         BEGIN
            IF EXISTS ( SELECT 1
                        FROM PACKDETAIL PD  WITH (NOLOCK)
                        LEFT OUTER JOIN PACKINFO   PIF WITH (NOLOCK) ON PD.PickSlipNo = PIF.PickSlipNo
                                                                    AND PD.CartonNo   = PIF.CartonNo
                        WHERE PD.PickSlipNo  = @c_PickSlipNo 
                        AND PIF.PickSlipNo IS NULL 
                     )
            BEGIN
               INSERT INTO PACKINFO (PickSlipNo, CartonNo, Qty, CartonType, [Cube], [Weight]) 
               SELECT PD.PickSlipNo
                  ,PD.CartonNo
                  ,Qty        = ISNULL(SUM(PD.Qty),0)
                  ,CartonType = @c_CartonType
                  ,[Cube]   = 0
                  ,[Weight] = 0
               FROM PACKDETAIL PD  WITH (NOLOCK)
               LEFT OUTER JOIN PACKINFO   PIF WITH (NOLOCK) ON PD.PickSlipNo = PIF.PickSlipNo
                                                           AND PD.CartonNo   = PIF.CartonNo
               JOIN SKU SKU WITH (NOLOCK) ON PD.StorerKey = SKU.StorerKey
                                          AND PD.Sku = SKU.Sku
               WHERE PD.PickSlipNo  = @c_PickSlipNo 
               AND PIF.PickSlipNo IS NULL
               GROUP BY PD.PickSlipNo
                     ,  PD.CartonNo

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_err = 70110   
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert PACKINFO. (isp_AltPackInfo_Wrapper)'   
 
                  GOTO QUIT_SP  
               END
            END                     
         END
         SET @b_Success = 1
      END
      ELSE IF @c_CartonType = @c_AltPIFCTNType 
      BEGIN
         SET @b_Success = 1
      END
      ELSE                                             
      BEGIN
         SET @b_Success = 2
      END
      GOTO QUIT_SP
   END

   IF NOT EXISTS (SELECT 1 FROM Sys.Objects (NOLOCK) WHERE object_id = object_id(@c_AltPackInfo_SP) AND [Type] = 'P')
   BEGIN
      SET @b_Success = 2
      GOTO QUIT_SP
   END

   SET @b_Success = 1
   SET @c_SQL = N'EXEC ' + @c_AltPackInfo_SP
              +'  @c_PickSlipNo = @c_PickSlipNo'  
              +', @n_CartonNo   = @n_CartonNo'
              +', @c_Storerkey  = @c_Storerkey'
              +', @c_Sku        = @c_Sku'
              + ',@c_CallFrom   = @c_CallFrom'      
              +', @c_CartonType = @c_CartonType OUTPUT'
              +', @n_Cube       = @n_Cube    OUTPUT'
              +', @n_Weight     = @n_Weight  OUTPUT' 
              +', @c_SkipCubeWgt= @c_SkipCubeWgt OUTPUT'  
              +', @b_Success    = @b_Success OUTPUT'
              +', @n_Err        = @n_Err     OUTPUT'
              +', @c_ErrMsg     = @c_ErrMsg  OUTPUT'

   SET @c_SQLParms= N'@c_PickSlipNo  NVARCHAR(10)'  
                  +', @n_CartonNo    INT'
                  +', @c_Storerkey   NVARCHAR(10)'
                  +', @c_Sku         NVARCHAR(20)'
                  +', @c_CallFrom    NVARCHAR(20)' 
                  +', @c_CartonType  NVARCHAR(10) OUTPUT'
                  +', @n_Cube        FLOAT OUTPUT'
                  +', @n_Weight      FLOAT OUTPUT'  
                  +', @c_SkipCubeWgt NVARCHAR(2)  OUTPUT' 
                  +', @b_Success     INT          OUTPUT'
                  +', @n_Err         INT          OUTPUT'
                  +', @c_ErrMsg      NVARCHAR(255)OUTPUT'

   EXEC sp_ExecuteSQL  @c_SQL
                     , @c_SQLParms
                     , @c_PickSlipNo  
                     , @n_CartonNo
                     , @c_Storerkey
                     , @c_Sku      
                     , @c_CallFrom
                     , @c_CartonType  OUTPUT
                     , @n_Cube        OUTPUT
                     , @n_Weight      OUTPUT
                     , @c_SkipCubeWgt OUTPUT 
                     , @b_Success     OUTPUT
                     , @n_Err         OUTPUT
                     , @c_ErrMsg      OUTPUT

   IF @b_Success = 0
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 70120   
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing ' + @c_AltPackInfo_SP + '. (isp_AltPackInfo_Wrapper)'   
                  + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
      GOTO QUIT_SP  
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_AltPackInfo_Wrapper'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   IF @b_Success IN (0,2) OR @c_CallFrom NOT IN ('PackInfoCheckReq', 'ESingleGetPackInfo', 'GetPackInfo')
   BEGIN
      SET @c_SkipCubeWgt = '0'
   END
END -- procedure

GO