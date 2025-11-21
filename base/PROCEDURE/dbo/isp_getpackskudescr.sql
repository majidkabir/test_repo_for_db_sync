SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_GetPackSkuDescr                                     */
/* Creation Date: 2020-06-15                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-13491 - SG - PMI - Packing [CR]                         */
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
/************************************************************************/
CREATE PROC [dbo].[isp_GetPackSkuDescr]
           @c_Storerkey          NVARCHAR(15)
         , @c_Sku                NVARCHAR(20)
         , @c_SkuDescr           NVARCHAR(60)   OUTPUT
         , @c_ActualskuCode      NVARCHAR(20)   OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT = @@TRANCOUNT
         , @n_Continue        INT = 1

   SET @c_ActualskuCode = ''
   SET @c_SkuDescr      = ''

   SELECT TOP 1 
            @c_ActualSkuCode = SKU
         ,  @c_SkuDescr = Descr
   FROM SKU WITH (NOLOCK)
   WHERE Storerkey = @c_Storerkey
   AND   Sku = @c_Sku

   IF @c_ActualSkuCode = ''
   BEGIN
      SELECT TOP 1 
            @c_ActualSkuCode = SKU
         ,  @c_SkuDescr = Descr
      FROM SKU WITH (NOLOCK)
      WHERE Storerkey = @c_Storerkey
      AND   AltSku = @c_Sku
   END

   IF @c_ActualSkuCode = ''
   BEGIN
      SELECT TOP 1 
            @c_ActualSkuCode = SKU
         ,  @c_SkuDescr = Descr
      FROM SKU WITH (NOLOCK)
      WHERE Storerkey = @c_Storerkey
      AND   RetailSku = @c_Sku
   END

   IF @c_ActualSkuCode = ''
   BEGIN
      SELECT TOP 1 
            @c_ActualSkuCode = SKU
         ,  @c_SkuDescr = Descr
      FROM SKU WITH (NOLOCK)
      WHERE Storerkey = @c_Storerkey
      AND   ManufacturerSku = @c_Sku
   END

   IF @c_ActualSkuCode = ''
   BEGIN
      SELECT TOP 1
            @c_ActualSkuCode = SKU.SKU
         ,  @c_SkuDescr = SKU.Descr
      FROM UPC WITH (NOLOCK)
      JOIN SKU WITH (NOLOCK) ON  UPC.Storerkey = SKU.Storerkey
                             AND UPC.Sku = SKU.Sku
      WHERE UPC.Storerkey = @c_Storerkey
      AND   UPC.UPC = @c_Sku
   END
QUIT_SP:

END -- procedure

GO