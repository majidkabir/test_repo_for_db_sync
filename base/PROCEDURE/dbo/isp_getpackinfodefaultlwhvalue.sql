SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_GetPackInfoDefaultLWHValue                          */
/* Creation Date: 10-Dec-2020                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-15830 - Get LWH from Cartonization Table                */
/*        :                                                             */
/* Called By: w_popup_packinfo                                          */
/*          :                                                           */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_GetPackInfoDefaultLWHValue]
           @c_PickslipNo       NVARCHAR(10)
         , @c_CartonNo         NVARCHAR(10)
         , @c_CartonType       NVARCHAR(10)
         , @n_Length           FLOAT          = 0.00   OUTPUT
         , @n_Width            FLOAT          = 0.00   OUTPUT
         , @n_Height           FLOAT          = 0.00   OUTPUT
         , @c_DefaultLWH       NVARCHAR(10)            OUTPUT
  
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt       INT
         , @n_Continue        INT 
         , @c_Storerkey       NVARCHAR(15) = ''
         , @c_Option5         NVARCHAR(4000) = ''

   SET @n_StartTCnt = @@TRANCOUNT
   
   SELECT @c_Storerkey = Storerkey
   FROM PACKHEADER (NOLOCK)
   WHERE PickSlipNo = @c_PickslipNo
   
   SELECT @c_Option5 = ISNULL(StorerConfig.Option5,'')
   FROM Storerconfig (NOLOCK)
   WHERE StorerConfig.StorerKey = @c_Storerkey 
   AND StorerConfig.ConfigKey = 'Default_PackInfo'
   
   SELECT @c_DefaultLWH = dbo.fnc_GetParamValueFromString('@c_DefaultLWH', @c_Option5, @c_DefaultLWH)   
   
   IF ISNULL(@c_DefaultLWH,'') = 'Y'
   BEGIN
      SELECT @n_Length = ISNULL(CZ.CartonLength,0)
           , @n_Width  = ISNULL(CZ.CartonWidth,0) 
           , @n_Height = ISNULL(CZ.CartonHeight,0)
      FROM PACKDETAIL (NOLOCK)
      JOIN STORER (NOLOCK) ON (PACKDETAIL.StorerKey = STORER.StorerKey)
      LEFT JOIN CARTONIZATION CZ (NOLOCK) ON (STORER.CartonGroup = CZ.CartonizationGroup AND CZ.CartonType = @c_CartonType)
      WHERE PACKDETAIL.Pickslipno = @c_PickslipNo AND PACKDETAIL.CartonNo = @c_CartonNo 
   END
   ELSE 
   BEGIN
   	SELECT @n_Length     = 0.00
           , @n_Width      = 0.00
           , @n_Height     = 0.00
           , @c_DefaultLWH = 'N'
   END
             
QUIT_SP:

END -- procedure

GO