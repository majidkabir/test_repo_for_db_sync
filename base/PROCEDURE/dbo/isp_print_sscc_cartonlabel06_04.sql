SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: isp_Print_SSCC_CartonLabel06_04                     */  
/* Creation Date: 30-APR-2012                                            */  
/* Copyright: IDS                                                        */  
/* Written by: YTWan                                                     */  
/*                                                                       */  
/* Purpose: SOS#241579: IDSCN QS Carton label                            */  
/*                                                                       */  
/* Called By: r_dw_sscc_cartonlabel06_04                                 */
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */  
/* 28-Feb-2013  NJOW01   1.0  270640-Add division field                  */  
/*************************************************************************/  
CREATE PROC [dbo].[isp_Print_SSCC_CartonLabel06_04]
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


   DECLARE @c_CustSku   NVARCHAR(18)
         , @c_CustSize  NVARCHAR(18)

   SET @c_CustSku = ''
   SET @c_CustSize= ''

   SELECT TOP 1 
          @c_CustSku = ISNULL(RTRIM(OD.UserDefine01),'') 
         ,@c_CustSize= ISNULL(RTRIM(OD.UserDefine02),'')
   FROM PACKHEADER PH WITH (NOLOCK)  
   JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
   JOIN ORDERDETAIL OD WITH (NOLOCK)ON (OD.Orderkey = PH.Orderkey)
                                    AND(OD.Storerkey= PD.Storerkey)
                                    AND(OD.Sku      = PD.Sku)
   WHERE PH.Storerkey = @c_Storerkey   
   AND PH.PickSlipNo = @c_PickSlipNo   
   AND PD.CartonNo >= @c_StartCartonNo 
   AND PD.CartonNo <= @c_EndCartonNo
   GROUP BY ISNULL(RTRIM(OD.UserDefine01),'') 
         ,  ISNULL(RTRIM(OD.UserDefine02),'')


   SELECT BuyerPO   = ISNULL(RTRIM(ORDERS.BuyerPO),'')
       ,  CartonNo  = ISNULL(PD.CartonNo,0)
       ,  PackedQty = SUM(PD.Qty)
       ,  CustSku  =  @c_CustSku
       ,  CustSize = @c_CustSize + CASE WHEN COUNT(ISNULL(RTRIM(OD.UserDefine02),'')) > 1
                                        THEN '*' 
                                        ELSE ''
                                        END  
       ,  Division = CASE WHEN ISNULL(ORDERS.Stop,'') IN ('','99') THEN  --NJOW01  
                          '24'  
                     ELSE ORDERS.Stop END                                          
   FROM PACKHEADER PH WITH (NOLOCK)  
   JOIN ORDERS WITH (NOLOCK) ON (ORDERS.Orderkey = PH.Orderkey) 
   JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
   JOIN ORDERDETAIL OD WITH (NOLOCK)ON (OD.Orderkey = ORDERS.Orderkey)
                                  AND(OD.Storerkey= PD.Storerkey)
                                  AND(OD.Sku      = PD.Sku)
   WHERE PH.Storerkey = @c_Storerkey   
   AND PH.PickSlipNo = @c_PickSlipNo  
   AND PD.CartonNo >= @c_StartCartonNo 
   AND PD.CartonNo <= @c_EndCartonNo
   GROUP BY ISNULL(RTRIM(ORDERS.BuyerPO),'')
         ,  ISNULL(PD.CartonNo,0)
         ,  CASE WHEN ISNULL(ORDERS.Stop,'') IN ('','99') THEN  --NJOW01  
                '24'  
            ELSE ORDERS.Stop END  

END

GO