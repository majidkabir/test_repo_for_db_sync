SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_GetCTNType01                                            */
/* Creation Date: 14-JUN-2016                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: SOS#361901 - New ECOM Packing                               */
/*        :                                                             */
/* Called By: isp_Ecom_GetDefaultCartonType                             */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 01-JUN-2017 Wan01    1.1   WMS-1816 - CN_DYSON_Exceed_ECOM PACKING   */
/************************************************************************/
CREATE PROC [dbo].[isp_GetCTNType01] 
         @c_PickSlipNo  NVARCHAR(10) 
      ,  @n_CartonNo    INT
      ,  @c_DefaultCartonType  NVARCHAR(10) = '' OUTPUT
      ,  @c_DefaultCartonGroup NVARCHAR(10) = '' OUTPUT  --(Wan01) 
      ,  @b_AutoCloseCarton    INT = 0           OUTPUT  --(Wan01)
      ,  @c_Storerkey   NVARCHAR(15) = ''                --(Wan01)      
      ,  @c_Sku         NVARCHAR(20) = ''                --(Wan01)   
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_QtyPicked    INT

         , @c_Orderkey     NVARCHAR(10)
         --, @c_Storerkey    NVARCHAR(15)
         --, @c_Sku          NVARCHAR(20)
         , @c_ItemClass    NVARCHAR(30)

         , @c_ListName     NVARCHAR(10)
         , @c_Sql          NVARCHAR(4000)

   SET @c_DefaultCartonType = ''
   SET @c_ListName = 'DFCTNTYPE'

   SET @c_Orderkey = ''
   SELECT @c_Orderkey = Orderkey
   FROM PACKHEADER WITH (NOLOCK)
   WHERE PickSlipNo = @c_PickSlipNo

   IF @c_Orderkey = ''
   BEGIN 
      GOTO QUIT_SP
   END 

   IF ISNULL(RTRIM(@c_Storerkey),'') = '' OR ISNULL(RTRIM(@c_Sku),'') = ''    --(Wan01) 
   BEGIN                                                                      --(Wan01)   
      SET @c_Storerkey = ''
      SET @c_Sku = ''
      SELECT TOP 1 @c_Storerkey = Storerkey
            ,@c_Sku = Sku
      FROM PACKDETAIL WITH (NOLOCK)
      WHERE PickSlipNo = @c_PickSlipNo
      AND   CartonNo = @n_CartonNo
   END                                                                        --(Wan01)   

   IF @c_Sku = ''
   BEGIN
      GOTO QUIT_SP
   END 
        
   SET @c_ItemClass = ''
   SELECT @c_ItemClass = RTRIM(ItemClass)
   FROM SKU WITH (NOLOCK)
   WHERE Storerkey = @c_Storerkey
   AND Sku = @c_Sku

   SET @c_Sql = N'SELECT TOP 1 @c_DefaultCartonType = CODELKUP.Short'
            + ' FROM CODELKUP   WITH (NOLOCK)' 
            + ' WHERE CODELKUP.ListName = N''ECOMCTNTYP'''
            + ' AND   CODELKUP.UDF01 =  N''' + RTRIM(@c_ItemClass)  + ''''
            + ' AND   EXISTS (SELECT 1'
            +               ' FROM PICKDETAIL WITH (NOLOCK)'
            +               ' WHERE PICKDETAIL.Orderkey = N''' + @c_Orderkey + ''''
            +               ' GROUP BY PICKDETAIL.Orderkey'
            +               ' HAVING ((SUM(PICKDETAIL.Qty) = CODELKUP.UDF03 AND CODELKUP.UDF02 = ''='')'
            +               ' OR  (SUM(PICKDETAIL.Qty) > CODELKUP.UDF03 AND CODELKUP.UDF02 = ''>''))'
            +               ')'

   EXEC sp_ExecuteSql @c_Sql
                     ,N'@c_DefaultCartonType NVARCHAR(10) OUTPUT'
                     ,@c_DefaultCartonType OUTPUT

   QUIT_SP:

END -- procedure

GO