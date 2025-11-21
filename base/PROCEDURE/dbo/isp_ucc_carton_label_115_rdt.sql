SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: isp_UCC_Carton_Label_115_rdt                        */
/* Creation Date:30-JUN-2022                                            */
/* Copyright: LFL                                                       */
/* Written by: CHONGCS                                                  */
/*                                                                      */
/* Purpose: WMS-20043 TH-NESP_Customize_dispatch_label(CR)              */
/*                                                                      */
/* Called By: r_dw_ucc_carton_label_115_rdt                             */
/*                                                                      */
/* Parameters: (Input)  @c_Storerkey      = Storerkey                   */
/*                      @c_Pickslipno     = Pickslipno                  */
/*                      @c_StartCartonNo  = CartonNoStart               */
/*                      @c_EndCartonNo    = CartonNoEnd                 */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver. Purposes                                 */
/* 2022-06-30   CHONGCS   1.1  Devops Scripts Combine                   */
/************************************************************************/
CREATE PROCEDURE [dbo].[isp_UCC_Carton_Label_115_rdt]
                 @c_Storerkey       NVARCHAR(15)
               , @c_Pickslipno      NVARCHAR(10)
               , @c_StartCartonNo   NVARCHAR(10)
               , @c_EndCartonNo     NVARCHAR(10)

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue  INT  =  1

   WHILE @@TRANCOUNT > 1
   BEGIN
      COMMIT TRAN
   END

   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      SELECT DISTINCT ORD.ExternOrderkey
            , ORD.Orderkey
            , ORD.C_Company
            , ORD.Consigneekey
            , ORD.UserDefine01
            , ORD.[Type] AS OrdType
            , ORD.C_Address1
            , ORD.C_Address2
            , ORD.C_City
            , ORD.C_State
            , ORD.C_Zip
            , ORD.C_Phone1
            , ISNULL(ORD.Notes,'') AS Notes
            , ISNULL(ORD.Notes2,'') AS Notes2
            , PD.LabelNo
            , PD.CartonNo
            , ORD.BuyerPO
            , ORD.[Route]   
            , Case When ORD.[Route] like '%BKK%' THEN 'BKK'  Else 'UPC' END AS Logo
            , Case When ORD.Invoiceamount > 0 Then 'COD' Else'NON-COD' End AS PaymentType
      FROM ORDERS ORD (NOLOCK)
      JOIN PACKHEADER PH (NOLOCK) ON PH.Orderkey = ORD.Orderkey
      JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno
      WHERE PD.Pickslipno = @c_Pickslipno
      AND PD.CartonNo BETWEEN CAST( @c_StartCartonNo AS INT) AND CAST( @c_EndCartonNo AS INT)
      AND PH.Storerkey = @c_Storerkey
      ORDER BY PD.CartonNo

   END

END

GO