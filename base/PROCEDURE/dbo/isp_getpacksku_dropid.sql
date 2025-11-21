SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_GetPackSku_DropID                                       */
/* Creation Date: 05-APR-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-1466 - CN & SG Logitech - Packing                       */
/*        :                                                             */
/* Called By:   ue_sku_rule                                             */
/*          :                                                           */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 05-JUL-2017 Wan      1.1   Fixed.Change error message                */
/* 07-JUL-2020 Wan02    1.2   WMS-13830 - SG- Logitech - Packing [CR]   */
/************************************************************************/
CREATE PROC [dbo].[isp_GetPackSku_DropID] 
            @c_DropID            NVARCHAR(20)
         ,  @c_StorerKey         NVARCHAR(15)
         ,  @c_Sku               NVARCHAR(60)   OUTPUT
         ,  @c_SerialNoRequired  NVARCHAR(3)   OUTPUT
         ,  @b_Success           INT = 0        OUTPUT 
         ,  @n_err               INT = 0        OUTPUT 
         ,  @c_errmsg            NVARCHAR(250) = '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt    INT
         , @n_Continue     INT
         
         , @n_SKUCnt       INT 
         , @c_DecodeSPName NVARCHAR(30)
         , @c_OriginalSku  NVARCHAR(60)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   BEGIN TRAN

   SET @c_OriginalSku = ISNULL(@c_Sku,'')
   
   SET @c_DecodeSPName = rdt.RDTGetConfig( 841, 'DecodeLabelNo', @c_StorerKey)
   IF @c_DecodeSPName = '0'
   BEGIN
      SET @c_DecodeSPName = ''
   END 

   IF @c_DecodeSPName <> ''
   BEGIN
      EXEC dbo.ispLabelNo_Decoding_Wrapper
          @c_SPName     = @c_DecodeSPName
         ,@c_LabelNo    = @c_OriginalSku
         ,@c_Storerkey  = @c_StorerKey
         ,@c_ReceiptKey = ''
         ,@c_POKey      = ''
         ,@c_LangCode   = ''                    -- Blank is default to English                 
         ,@c_oFieled01  = @c_Sku       OUTPUT   -- SKU
         ,@c_oFieled02  = ''
         ,@c_oFieled03  = ''
         ,@c_oFieled04  = ''
         ,@c_oFieled05  = ''
         ,@c_oFieled06  = ''
         ,@c_oFieled07  = ''
         ,@c_oFieled08  = ''
         ,@c_oFieled09  = ''
         ,@c_oFieled10  = ''
         ,@b_Success    = @b_Success   OUTPUT
         ,@n_ErrNo      = @n_Err       OUTPUT
         ,@c_ErrMsg     = @c_ErrMsg    OUTPUT

      IF @b_Success <> 1
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 50005
         SET @c_ErrMsg = 'NSQL' +  CONVERT(CHAR(5),@n_Err)  + ':'  
                        + 'Error Executing ispLabelNo_Decoding_Wrapper.(isp_GetPackSku_DropID)'
         GOTO QUIT_SP
      END
   END

   IF @c_OriginalSku = @c_Sku
   BEGIN
      EXEC isp_SKUDecode_Wrapper
            @c_Storerkey = @c_Storerkey
         ,  @c_Sku       = @c_OriginalSku
         ,  @c_NewSku    = @c_Sku      OUTPUT
         ,  @b_Success   = @b_Success  OUTPUT
         ,  @n_Err       = @n_Err      OUTPUT
         ,  @c_ErrMsg    = @c_ErrMsg   OUTPUT

      IF @b_Success <> 1
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 50010
         SET @c_ErrMsg = 'NSQL' +  CONVERT(CHAR(5),@n_Err)  + ':'  
                        + 'Error Executing isp_SKUDecode_Wrapper.(isp_GetPackSku_DropID)'
         GOTO QUIT_SP
      END
   END

   EXEC rdt.rdt_GETSKUCNT
       @cStorerKey  = @c_StorerKey
      ,@cSKU        = @c_SKU
      ,@nSKUCnt     = @n_SKUCnt        OUTPUT
      ,@bSuccess    = @b_Success       OUTPUT
      ,@nErr        = @n_Err           OUTPUT
      ,@cErrMsg     = @c_ErrMsg        OUTPUT

   IF @b_Success <> 1
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 50085
      SET @c_ErrMsg = 'NSQL' +  CONVERT(CHAR(5),@n_Err)  + ':'  
                     + 'Error Executing rdt_GETSKUCNT.(isp_GetPackSku_DropID)'
      GOTO QUIT_SP
   END

   IF @n_SKUCnt = 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 50090
      SET @c_ErrMsg = 'NSQL' +  CONVERT(CHAR(5),@n_Err)  + ':'  
                     + 'Invalid Sku Barcode.(isp_GetPackSku_DropID)'
      GOTO QUIT_SP
   END 

   IF @n_SKUCnt > 1
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 50095
      SET @c_ErrMsg = 'NSQL' +  CONVERT(CHAR(5),@n_Err)  + ':'  
                     + 'Multi Sku Barcode found.(isp_GetPackSku_DropID)'
      GOTO QUIT_SP
   END 

   EXEC rdt.rdt_GETSKU
       @cStorerKey  = @c_StorerKey
      ,@cSKU        = @c_SKU        OUTPUT
      ,@bSuccess    = @b_Success    OUTPUT
      ,@nErr        = @n_Err        OUTPUT
      ,@cErrMsg     = @c_ErrMsg     OUTPUT

   IF ISNULL(@c_DropID,'') <> '' 
   BEGIN
      --IF NOT EXISTS  (  SELECT 1
      --                  FROM PICKDETAIL WITH (NOLOCK)
      --                  WHERE DropID = @c_DropID
      --                  AND   Storerkey = @c_Storerkey
      --                  AND   Sku = @c_Sku
      --               )
      IF NOT EXISTS (SELECT 1
                     FROM PICKDETAIL PD WITH (NOLOCK)
                     JOIN dbo.Fnc_GetWaveOrder_DropID( @c_DropID ) ORD ON (PD.Orderkey = ORD.Orderkey)
                     WHERE PD.DropID = @c_DropID
                     AND   PD.Storerkey = @c_Storerkey
                     AND   PD.Sku = @c_Sku
                     )
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 50100
         SET @c_ErrMsg = 'NSQL' +  CONVERT(CHAR(5),@n_Err)  + ':'  
                       --+ 'Sku not found for DropID #: ' + RTRIM(@c_DropID)  --(Wan02)
                       + 'Wrong Sku for DropID #: ' + RTRIM(@c_DropID)        --(Wan02)
                       + '.(isp_GetPackSku_DropID)'
         GOTO QUIT_SP
      END 

      IF (dbo.fnc_GetOrder_DropID (@c_DropID, @c_Storerkey, @c_Sku, 1)) = ''
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 50110
         SET @c_ErrMsg = 'NSQL' +  CONVERT(CHAR(5),@n_Err)  + ':'  
                       + 'No Order # for Sku From DropID: ' + RTRIM(@c_DropID)      -- (Wan01)
                       + '.(isp_GetPackSku_DropID)'
         GOTO QUIT_SP
      END

      SELECT @c_SerialNoRequired = ISNULL(BUSR7,'')
      FROM SKU WITH (NOLOCK) 
      WHERE Storerkey = @c_Storerkey
      AND Sku = @c_Sku
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

      --EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_GetPackSku_DropID'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
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