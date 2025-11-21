SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_PrintshipLabel_kerrypdf_RDT                         */
/* Creation Date: 01-JUL-2022                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-20107 - THâ€“PUMA-Kerry Shipping Label                    */
/*        :                                                             */
/* Called By: r_dw_print_shiplabel_kerrypdf_rdt                         */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 01-JUL-2022 CSCHONG  1.1   Devops Scripts combine                    */
/* 02-AUG-2022 CSCHONG  1.2   WMS-20107 add new field (CS01)            */
/************************************************************************/
CREATE   PROC [dbo].[isp_PrintshipLabel_kerrypdf_RDT]
                  @c_Storerkey       NVARCHAR(20)
                , @c_Pickslipno      NVARCHAR(20)
                , @c_CartonNo        NVARCHAR(10)

AS  
BEGIN  
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF     

   DECLARE    
           @n_StartTCnt       INT  
         , @n_Continue        INT  
   
         , @n_MaxLine         INT 
         , @n_maxctn          INT
         , @c_PmtTerm         NVARCHAR(10)
         , @n_CurCtn          INT
         , @n_ttlctn          INT = 1

  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  
            
   SET @n_Maxline = 17    


   SELECT @n_ttlctn = COUNT(DISTINCT PD.Cartonno)
   FROM orders O  WITH (nolock) 
   JOIN FACILITY F WITH (nolock) ON O.Facility=F.Facility 
   JOIN PackHeader PH WITH (nolock) on O.StorerKey=PH.StorerKey and O.OrderKey=PH.OrderKey
   JOIN PackDetail PD WITH (nolock) on PH.StorerKey = PD.StorerKey and PH.PickSlipNo = PD.PickSlipNo 
   JOIN storer S WITH (nolock) on O.Storerkey=S.Storerkey
   JOIN CODELKUP C WITH (nolock) on O.StorerKey=C.Storerkey and O.ShipperKey=C.Code
   where ph.storerkey=@c_Storerkey and O.DocType='E' and C.LISTNAME='PUSFCCLAB' and PH.Status='9'
   AND ph.PickSlipNo= @c_Pickslipno

   select O.C_City+' '+O.C_State AS c_citystate,
          F.Address1+' '+F.Address2 AS FAdd1,
          F.Descr AS Fdescr,
          O.ExternOrderkey,
          F.Address3+' '+F.Address4 AS FAdd3,
          O.C_Phone1+','+O.C_Phone2 AS CPhone,
          F.City+' '+F.State+' '+F.Zip AS FCity,
          ISNULL(S.Fax2,'') AS Fax2,
          O.C_contact1+' '+O.C_Company AS CCompany,
          O.C_Address1+' '+O.C_Address2 AS CAdd1,
          O.C_Address3+' '+O.C_Address4 AS CAdd3,
          O.C_Zip ,
          PD.LabelNo,
          O.Notes+' '+O.Notes2 AS OHNotes,
          O.TrackingNo,
          @n_ttlctn  AS ttlctn,--COUNT(distinct PD.CartonNo) AS ttlctn,
          PD.CartonNo,
          OIF.EcomOrderId                                                               --CS01  
   FROM orders O  WITH (nolock) 
   JOIN FACILITY F WITH (nolock) ON O.Facility=F.Facility 
   JOIN PackHeader PH WITH (nolock) on O.StorerKey=PH.StorerKey and O.OrderKey=PH.OrderKey
   JOIN PackDetail PD WITH (nolock) on PH.StorerKey = PD.StorerKey and PH.PickSlipNo = PD.PickSlipNo
   JOIN storer S WITH (nolock) on O.Storerkey=S.Storerkey
   JOIN CODELKUP C WITH (nolock) on O.StorerKey=C.Storerkey and O.ShipperKey=C.Code
   JOIN OrderInfo OIF WITH (NOLOCK) ON OIF.OrderKey = O.OrderKey                                --CS01
   where O.storerkey=@c_Storerkey and O.DocType='E' and C.LISTNAME='PUSFCCLAB' and PH.Status IN('0','5','9')   --CS01
   AND ph.PickSlipNo= @c_Pickslipno AND PD.CartonNo = CAST(@c_CartonNo AS INT)
   group by O.TrackingNo,F.Descr,F.Address1+' '+F.Address2,F.Address3+' '+F.Address4,F.City+' '+F.State,F.Zip,S.Fax2,
            O.C_contact1+' '+O.C_Company,O.C_Address1+' '+O.C_Address2,O.C_Address3+' '+O.C_Address4,O.C_City+' '+O.C_State,O.C_Zip,
            O.C_Phone1+','+O.C_Phone2,PD.LabelNo,PD.CartonNo,O.Notes+' '+O.Notes2,O.ExternOrderkey,OIF.EcomOrderId                  --CS01
  
  
QUIT:  
  


END -- procedure  


GO