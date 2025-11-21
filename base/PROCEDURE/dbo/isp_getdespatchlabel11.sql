SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_GetDespatchLabel11                             */
/* Creation Date: 10-Aug-2012                                           */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose:  SOS#252748 CitiPost Despatch Label                         */
/*                                                                      */
/* Input Parameters:  @c_StorerKey, @c_Orderkey , @c_refNo              */
/*                                                                      */
/* Called By:  dw = r_dw_despatch_label11 (rdt, wms)                    */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_GetDespatchLabel11]   
(  
    @c_StorerKey  NVARCHAR(15)  
   ,@c_OrderKey   NVARCHAR(10)  
   ,@c_RefNo      NVARCHAR(20) = ''      
    
)      
AS      
BEGIN  
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS ON      
   SET CONCAT_NULL_YIELDS_NULL OFF  

            
   IF RTRIM(ISNULL(@c_OrderKey,'')) = '' AND RTRIM(ISNULL(@c_RefNo,'')) <> ''  
   BEGIN      
      SELECT @c_OrderKey = PACKHEADER.OrderKey   
          ,  @c_StorerKey = ORDERS.StorerKey   
      FROM PACKHEADER WITH (NOLOCK)   
      JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)  
      JOIN ORDERS WITH (NOLOCK) ON (PACKHEADER.OrderKey = ORDERS.OrderKey)  
      WHERE PACKDETAIL.RefNo = @c_RefNo   
   END  
   
   SELECT TOP 1 
      --  BarCode = SUBSTRING(CODELKUP.SHORT,1,3) + RIGHT(ORDERS.Orderkey,8) + LEFT( UPPER(REPLACE(ISNULL(RTRIM(ORDERS.C_Zip),''),' ','')) + '00000000',8)
        BarCode    = PACKDETAIL.LabelNo
      , C_Contact1 = ISNULL(RTRIM(ORDERS.C_Contact1),'') 
      , C_Address1 = ISNULL(RTRIM(ORDERS.C_Address1),'')  
      , C_Address2 = ISNULL(RTRIM(ORDERS.C_Address2),'')  
      , C_Address3 = ISNULL(RTRIM(ORDERS.C_Address3),'')  
      , C_Address4 = ISNULL(RTRIM(ORDERS.C_Address4),'')  
      , C_City     = ISNULL(RTRIM(ORDERS.C_City),'') 
      , C_Zip      = ISNULL(RTRIM(ORDERS.C_Zip),'') 
   FROM ORDERS WITH (NOLOCK)
   JOIN PACKHEADER WITH (NOLOCK) ON (ORDERS.OrderKey = PACKHEADER.OrderKey) 
   JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo) 
   --JOIN CODELKUP WITH (NOLOCK)   ON (CODELKUP.ListName = 'SHIPPING')
   --                              AND(CODELKUP.Code = ORDERS.IncoTerm)
   --                              AND(CODELKUP.UDF01 = 'CITIPOST') 
   WHERE Orders.Storerkey = @c_StorerKey
   AND ORDERS.Orderkey = @c_Orderkey
      
Quit:

END -- procedure     

GO