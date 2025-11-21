SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: isp_Print_SSCC_CartonLabel06_02                     */  
/* Creation Date: 18-OCT-2013                                            */  
/* Copyright: IDS                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: SOS#291999 - QS Label (Upgrade to SAP).                      */
/*          Sync with datamart datawindow to call SP                     */
/*          datamart                                                     */  
/* Called By: r_dw_sscc_cartonlabel06_02                                 */
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author  Ver  Purposes                                    */  
/*************************************************************************/  
CREATE PROC [dbo].[isp_Print_SSCC_CartonLabel06_02]
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

   SELECT BuyerPO        = ISNULL(RTRIM(ORDERS.BuyerPO),'')  
      ,  ExternOrderkey = ISNULL(RTRIM(ORDERS.ExternOrderkey),'') 
      ,  MarkForKey     = ISNULL(RTRIM(ORDERS.MarkForKey),'')                         
      ,  M_Company      = ISNULL(RTRIM(ORDERS.M_Company),'') 
      ,  UserDefine03   = ISNULL(RTRIM(ORDERS.UserDefine03),'') 
      ,  SalesMan       = ISNULL(RTRIM(ORDERS.SalesMan),'') 
      ,  CartonNo       = ISNULL(PD.CartonNo,0) 
      ,	Qty = SUM(PD.Qty) 
      ,  StdGrossWgt = SUM(SKU.StdGrossWgt * PD.Qty) 
      FROM PACKHEADER PH WITH (NOLOCK)   
      JOIN ORDERS ORDERS WITH (NOLOCK) ON (ORDERS.Orderkey = PH.Orderkey)  
      JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo) 
      JOIN SKU SKU WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey) 
      							 AND(PD.Sku = SKU.Sku) 
     WHERE PH.Storerkey  = @c_Storerkey 
       AND PH.PickSlipNo = @c_PickSlipNo 
       AND PD.CartonNo  >= @c_StartCartonNo  
       AND PD.CartonNo  <= @c_EndCartonNo 
     GROUP BY ISNULL(RTRIM(ORDERS.BuyerPO),'') 
      ,  ISNULL(RTRIM(ORDERS.ExternOrderkey),'') 
      ,  ISNULL(RTRIM(ORDERS.MarkForKey),'') 
      ,  ISNULL(RTRIM(ORDERS.M_Company),'')  
      ,  ISNULL(RTRIM(ORDERS.UserDefine03),'') 
      ,  ISNULL(RTRIM(ORDERS.SalesMan),'') 
      ,  ISNULL(PD.CartonNo,0) 
            
END

GO