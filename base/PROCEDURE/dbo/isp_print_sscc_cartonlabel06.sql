SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: isp_Print_SSCC_CartonLabel06                        */  
/* Creation Date: 18-NOV-2013                                            */  
/* Copyright: IDS                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: SOS#291999 - QS Label (Upgrade to SAP).                      */
/*          Sync with datamart datawindow to call SP                     */
/*          datamart                                                     */  
/* Called By: r_dw_sscc_cartonlabel06                                    */
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */  
/*************************************************************************/  
CREATE PROC [dbo].[isp_Print_SSCC_CartonLabel06]
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
           PH.Storerkey
         , PH.PickSlipNo
         , CartonNo = CONVERT(VARCHAR(10), PD.CartonNo) 
         , UserDefine10 = ISNULL(RTRIM(ORDERS.UserDefine10),'') 
   FROM PACKHEADER PH WITH (NOLOCK)
   JOIN ORDERS ORDERS WITH (NOLOCK) ON (PH.Orderkey = ORDERS.Orderkey)   
   JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo= PD.PickSlipNo)
   WHERE PH.Storerkey= @c_Storerkey
   AND PH.PickSlipNo = @c_PickSlipNo 
   AND PD.CartonNo  >= @c_StartCartonNo 
   AND PD.CartonNo  <= @c_EndCartonNo
END

GO