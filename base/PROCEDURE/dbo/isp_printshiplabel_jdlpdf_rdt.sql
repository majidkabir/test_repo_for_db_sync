SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_PrintShipLabel_JDLPDF_RDT                           */
/* Creation Date: 29-Sep-2022                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-20836 - ID PUMA-JDL Shipping Label                      */
/*        :                                                             */
/* Called By: r_dw_print_shiplabel_jdlpdf_rdt                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 29-Sep-2022 WLChooi  1.0   DevOps Combine Script                     */
/************************************************************************/
CREATE   PROC [dbo].[isp_PrintShipLabel_JDLPDF_RDT]
   @c_Storerkey  NVARCHAR(20)
 , @c_Pickslipno NVARCHAR(20)
 , @c_CartonNo   NVARCHAR(10) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt INT
         , @n_Continue  INT

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

   SELECT DISTINCT TRIM(ISNULL(OH.C_contact1, '')) + ' (' + TRIM(ISNULL(OH.C_Phone1, '')) + ')' AS C_Contact1
                 , TRIM(ISNULL(OH.C_Company, '')) AS C_Company
                 , TRIM(ISNULL(OH.C_Address2, '')) + ', ' + TRIM(ISNULL(OH.C_Address3, '')) + ', '
                   + TRIM(ISNULL(OH.C_Address4, '')) AS C_Addresses
                 , TRIM(ISNULL(OH.C_Address1, '')) AS C_Address1
                 , TRIM(ISNULL(OH.C_City, '')) AS C_City
                 , TRIM(ISNULL(OH.C_State, '')) AS C_State
                 , TRIM(ISNULL(OH.C_Zip, '')) AS C_Zip
                 , 'AWB Number : ' + TRIM(OH.TrackingNo) AS AWBNumber
                 , TRIM(OH.TrackingNo) AS TrackingNo
                 , 'REG' AS DeliveryMode
                 , TRIM(ISNULL(CL.UDF05, '')) + '-' + OH.OrderKey AS OrderNumber
                 , TRIM(ISNULL(OIF.CarrierName,'')) AS CarrierName
                 , TRIM(ISNULL(PH.OrderRefNo,'')) + '-' + CONVERT(NVARCHAR(5),PD.CartonNo) AS OrderRef
   FROM PackDetail PD (NOLOCK)
   JOIN PackHeader PH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PH.OrderKey
   LEFT JOIN OrderInfo OIF (NOLOCK) ON OH.OrderKey = OIF.OrderKey
   LEFT JOIN CODELKUP CL (NOLOCK) ON  CL.LISTNAME = 'PUMASHPKEY'
                                  AND CL.Storerkey = OH.StorerKey
                                  AND CL.Short = OIF.CarrierName
   WHERE PD.StorerKey = @c_Storerkey
   AND   PD.PickSlipNo = @c_Pickslipno
   AND   PD.CartonNo = CAST(@c_CartonNo AS INT)

   QUIT_SP:
END -- procedure  

GO