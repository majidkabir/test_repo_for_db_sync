SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_UCC_Carton_Label_119_2_rdt                     */
/* Creation Date: 17-Jan-2023                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-21580 - CN_PUMA_CartonLabel_CR                          */
/*                                                                      */
/* Called By: r_dw_ucc_carton_label_119_rdt                             */
/*                                                                      */
/* Parameters: (Input)  @c_Pickslipno     = Pickslipno                  */
/*                      @c_CartonNo       = CartonNo                    */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver. Purposes                                 */
/* 17-Jan-2023  WLChooi   1.0  DevOps Combine Script                    */
/************************************************************************/
CREATE   PROCEDURE [dbo].[isp_UCC_Carton_Label_119_2_rdt]
   @c_Pickslipno NVARCHAR(10)
 , @c_CartonNo   NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue INT = 1
         , @n_Err      INT
         , @c_Errmsg   NVARCHAR(250)

   SELECT PackHeader.LoadKey
        , PackHeader.StorerKey
        , C_Company = ISNULL(RTRIM(ORDERS.C_Company), '')
        , c_State = ISNULL(RTRIM(ORDERS.C_State), '')
        , c_city = ISNULL(RTRIM(ORDERS.C_City), '')
        , C_Address1 = ISNULL(RTRIM(ORDERS.C_Address1), '')
        , C_Address2 = ISNULL(RTRIM(ORDERS.C_Address2), '')
        , C_Address3 = ISNULL(RTRIM(ORDERS.C_Address3), '')
        , C_Address4 = ISNULL(RTRIM(ORDERS.C_Address4), '')
        , C_Contact1 = ISNULL(RTRIM(ORDERS.C_contact1), '')
        , C_Phone1 = ISNULL(RTRIM(ORDERS.C_Phone1), '')
        , C_Phone2 = ISNULL(RTRIM(ORDERS.C_Phone2), '')
        , Carton = @c_CartonNo
                   + ' / '
                   --//+ CASE WHEN MAX(ORDERS.Status) >= '5' THEN CONVERT(NVARCHAR(10),COUNT(DISTINCT PACKDETAIL.CartonNo)) ELSE '     ' END
                   + CASE WHEN MAX(PackHeader.Status) = '9' THEN
                             CONVERT(NVARCHAR(10), COUNT(DISTINCT PackDetail.CartonNo))
                          ELSE '    ' END
        , ISNULL(C.Description, '') AS ordcategory
   FROM PackHeader WITH (NOLOCK)
   JOIN LOADPLANDETAIL WITH (NOLOCK) ON (LoadPlanDetail.LoadKey = PACKHEADER.LoadKey)
   JOIN ORDERS WITH (NOLOCK) ON (LoadPlanDetail.OrderKey = ORDERS.OrderKey)
   JOIN PackDetail WITH (NOLOCK) ON (PackHeader.PickSlipNo = PackDetail.PickSlipNo)
   LEFT JOIN CODELKUP C WITH (NOLOCK) ON  C.LISTNAME = 'OBType'
                                      AND C.Storerkey = ORDERS.StorerKey
                                      AND C.Code = ORDERS.Stop
   WHERE PackHeader.PickSlipNo = @c_Pickslipno
   GROUP BY PackHeader.LoadKey
          , PackHeader.StorerKey
          , ORDERS.C_Company
          , ISNULL(RTRIM(ORDERS.C_State), '')
          , ISNULL(RTRIM(ORDERS.C_City), '')
          , ISNULL(RTRIM(ORDERS.C_Address1), '')
          , ISNULL(RTRIM(ORDERS.C_Address2), '')
          , ISNULL(RTRIM(ORDERS.C_Address3), '')
          , ISNULL(RTRIM(ORDERS.C_Address4), '')
          , ISNULL(RTRIM(ORDERS.C_contact1), '')
          , ISNULL(RTRIM(ORDERS.C_Phone1), '')
          , ISNULL(RTRIM(ORDERS.C_Phone2), '')
          , ISNULL(C.Description, '')

END

GO