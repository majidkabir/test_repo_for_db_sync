SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_UCC_Carton_Label_61_rdt                        */
/* Creation Date: 20-JUNE-2017                                          */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-2119 - HKCPI - Lulu - New Store Label                   */
/*                                                                      */
/* Input Parameters: Storerkey ,PickSlipNo, CartonNoStart, CartonNoEnd  */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:  r_dw_ucc_carton_label_61_rdt                             */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 26/08/2019   WLChooi  1.1  WMS-10324 - Add new mapping fields (WL01) */
/* 24/03/2021   mingle   1.2  WMS-16540 - Add labelno            (ML01) */ 
/************************************************************************/

CREATE PROC [dbo].[isp_UCC_Carton_Label_61_rdt] (  
       @c_storerkey      NVARCHAR(20)  
      ,  @c_PickSlipNo     NVARCHAR(20)  
      ,  @c_StartCartonNo  NVARCHAR(20)  
      ,  @c_EndCartonNo    NVARCHAR(20)  
)  
AS  
BEGIN  
  
   SET NOCOUNT ON  
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF        
  
  CREATE TABLE #TMP_UCCCTNLBL61_rdt (  
          rowid           int identity(1,1),  
          consigneekey    NVARCHAR(10) NULL,  
          c_company       NVARCHAR(45) NULL,  
          OHNotes         NVARCHAR(100) NULL,  
          Pickslipno      NVARCHAR(20) NULL,  
          B_Company       NVARCHAR(45) NULL,    --WL01  
          B_Addresses     NVARCHAR(255) NULL,   --WL01  
          labelno         NVARCHAR(20) NULL     --ML01  
    )                      
  
   INSERT INTO #TMP_UCCCTNLBL61_rdt(consigneekey, c_company, OHNotes, Pickslipno, B_Company, B_Addresses,labelno)     --ML01      --WL01  
   SELECT DISTINCT substring(oh.ConsigneeKey,3,5), oh.C_Company, oh.Notes2, ph.PickSlipNo,  
                    ISNULL(ST.B_Company,''), LTRIM(RTRIM(ISNULL(ST.B_Address1,''))) + LTRIM(RTRIM(ISNULL(ST.B_Address2,''))) +  --WL01  
                    LTRIM(RTRIM(ISNULL(ST.B_Address3,''))) + LTRIM(RTRIM(ISNULL(ST.B_Address4,''))),                          --WL01  
                    pd.labelno     --ML01  
 FROM PACKHEADER PH WITH (NOLOCK)   
 JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo=PH.PickSlipNo  
 JOIN ORDERS OH WITH (NOLOCK) ON OH.OrderKey=PH.OrderKey  
 JOIN CODELKUP C1 WITH (NOLOCK) ON C1.Listname = 'LULUSTLBL' AND c1.code=oh.ConsigneeKey  
 JOIN Codelkup C2 WITH (NOLOCK) ON C2.Listname = 'LULUSTLBL' AND c2.code2=Oh.[Type]  
   LEFT JOIN STORER ST WITH (NOLOCK) ON ST.Storerkey = OH.Consigneekey                      --WL01  
 WHERE PD.Pickslipno = @c_PickSlipNo  
   AND   PD.Storerkey = @c_StorerKey  
   AND   PD.cartonno between CONVERT(INT,@c_StartCartonNo) AND CONVERT(INT,@c_EndCartonNo)  
    
 SELECT Pickslipno, consigneekey, c_company, OHNotes, B_Company, B_Addresses,labelno     --ML01   --WL01  
 FROM   #TMP_UCCCTNLBL61_rdt  
   
END  
  


GO