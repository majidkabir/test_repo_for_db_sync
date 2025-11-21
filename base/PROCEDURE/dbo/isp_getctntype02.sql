SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_GetCTNType02                                            */
/* Creation Date: 01-JUN-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: WMS-1816 - CN_DYSON_Exceed_ECOM PACKING                     */
/*        :                                                             */
/* Called By: isp_Ecom_GetDefaultCartonType                             */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_GetCTNType02] 
         @c_PickSlipNo  NVARCHAR(10) 
      ,  @n_CartonNo    INT
      ,  @c_DefaultCartonType  NVARCHAR(10) = '' OUTPUT
      ,  @c_DefaultCartonGroup NVARCHAR(10) = '' OUTPUT  
      ,  @b_AutoCloseCarton    INT = 0           OUTPUT   
      ,  @c_Storerkey   NVARCHAR(15) = ''                
      ,  @c_Sku         NVARCHAR(20) = ''                
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_QtyPicked    INT

         , @c_Orderkey     NVARCHAR(10)
         , @c_ItemClass    NVARCHAR(30)


   SET @c_DefaultCartonType = ''
   SET @c_DefaultCartonGroup= ''

   IF ISNULL(RTRIM(@c_Sku),'') = '' 
   BEGIN
      GOTO QUIT_SP
   END 
         
   SET @c_ItemClass = ''
   SELECT TOP 1
           @c_DefaultCartonType = CZ.CartonType
         , @c_DefaultCartonGroup= CZ.CartonizationGroup
   FROM SKU WITH (NOLOCK)
   JOIN CARTONIZATION  CZ WITH (NOLOCK) ON (Sku.CartonGroup = CZ.CartonizationGroup)
   WHERE SKU.Storerkey = @c_Storerkey
   AND SKU.Sku = @c_Sku
   AND SKU.CartonGroup <> 'STD'

   IF ISNULL(@c_DefaultCartonType,'') <> ''
   BEGIN
      SET @b_AutoCloseCarton = 1
   END

   QUIT_SP:
END -- procedure

GO