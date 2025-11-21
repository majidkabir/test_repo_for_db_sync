SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Stored Procedure: isp_UCC_Carton_Label_89_rdt                        */  
/* Creation Date:                                                       */  
/* Copyright: LFL                                                       */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-10233 TH NESP Shipper Label                             */
/*                                                                      */  
/* Called By: r_dw_ucc_carton_label_89_rdt                              */   
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
/* 2020-11-13   WLChooi   1.1  WMS-15673 - Add ORDERS.Route (WL01)      */ 
/************************************************************************/  
CREATE PROCEDURE [dbo].[isp_UCC_Carton_Label_89_rdt]  
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
            , ORD.[Route]   --WL01
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