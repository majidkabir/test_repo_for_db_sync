SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: isp_Print_SSCC_CartonLabel06_01                     */  
/* Creation Date: 18-NOV-2013                                            */  
/* Copyright: IDS                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: SOS#291999 - QS Label (Upgrade to SAP).                      */
/*          Sync with datamart datawindow to call SP                     */
/*          datamart                                                     */  
/* Called By: r_dw_sscc_cartonlabel06_01                                 */
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author  Ver   Purposes                                   */  
/*************************************************************************/  
CREATE PROC [dbo].[isp_Print_SSCC_CartonLabel06_01]
      @c_Storerkey      NVARCHAR(15)
   ,  @c_PickSlipNo     NVARCHAR(10)
   ,  @c_StartCartonNo  NVARCHAR(10)
   ,  @c_EndCartonNo    NVARCHAR(10)
AS  
BEGIN
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   SELECT DISTINCT
            ORDERS.OrderGroup
            ,  ORDERS.BuyerPO
            ,  Consigneekey = SUBSTRING(ORDERS.Consigneekey,3,13)
            ,  ORDERS.C_Company                                   
            ,  ORDERS.C_Zip
            ,  MarkForKey                                      
            ,  ORDERS.M_Company
            ,  ORDERS.M_Address1
            ,  ORDERS.M_Address2
            ,  ORDERS.M_Address3
            ,  ORDERS.M_Address4
            ,  ORDERS.M_State
            ,  ORDERS.M_Zip
            ,  ORDERS.M_Country
            ,  PostCode = '421036' + CASE WHEN ISNULL(ORDERS.M_Zip,'')='' 
                                          THEN ISNULL(ORDERS.B_Zip,'')
                                          ELSE ORDERS.M_Zip END
            ,  PostCode_EAN128 = '~202' + '421036' + CASE WHEN ISNULL(ORDERS.M_Zip,'')='' 
                                          THEN ISNULL(ORDERS.B_Zip,'')
                                          ELSE ORDERS.M_Zip END
            ,  ORDERS.Userdefine01
            ,  ORDERS.Userdefine02
            ,  ORDERS.Userdefine03
            ,  ORDERS.Userdefine04
            ,  STORER.Company
            ,  STORER.Address1
            ,  STORER.Address2
            ,  STORER.Address3
            ,  STORER.Address4
            ,  STORER.State
            ,  STORER.Zip
            ,  STORER.Country
            ,  Notes1 = CONVERT(NVARCHAR(4000), STORER.Notes1)
            ,  LabelNo = PD.LabelNo
            ,  LabelNo_EAN128 = '~202' + PD.LabelNo
            ,  Market = CL.Code
            ,  ORDERS.DeliveryPlace  
            ,  ORDERS.SalesMan
            ,  ORDERS.UserDefine10
            ,  ORDERS.ExternOrderkey
      FROM PACKHEADER PH WITH (NOLOCK)
      JOIN ORDERS ORDERS WITH (NOLOCK) ON (ORDERS.Orderkey = PH.Orderkey)
      JOIN STORER STORER WITH (NOLOCK) ON (ORDERS.Facility = STORER.Storerkey)
      JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
      LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.ListName = 'QSFAC') AND (CL.Short = ORDERS.Facility)
      WHERE PH.Storerkey  = @c_Storerkey
      AND PH.PickSlipNo = @c_PickSlipNo
      AND PD.CartonNo >= @c_StartCartonNo
      AND PD.CartonNo <= @c_EndCartonNo 


END

GO