SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_Packing_List_107_RDT                                */
/* Creation Date: 29-JUL-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-17514-[CN] APEDEMOD_Packing list for CN Lafayette       */
/*        :                                                             */
/* Called By: r_dw_packing_list_107_RDT                                 */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_Packing_List_107_RDT]
            @c_PickSlipNo   NVARCHAR(10),
            @c_cartonNoStart NVARCHAR(5) = '', 
            @c_cartonNoEnd NVARCHAR(5)  =''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 
         , @c_SummPAck        NVARCHAR(5)
         , @c_B1              NVARCHAR(80)  
         , @c_B2              NVARCHAR(80)  
         , @c_B3              NVARCHAR(80)  


   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END


  SET @c_SummPAck  = 'N'

   IF ISNULL(@c_cartonNoStart,'') = '' SET @c_cartonNoStart = '1'
   IF ISNULL(@c_cartonNoEnd,'') = '' SET @c_cartonNoEnd = '99999'

   IF @c_cartonNoStart ='1' AND @c_cartonNoEnd ='99999' 
   BEGIN 
        SET @c_SummPAck  = 'Y'     
   END

     SELECT  @c_B1 = ISNULL(MAX(CASE WHEN CL.Code = 'B01'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_B2 = ISNULL(MAX(CASE WHEN CL.Code = 'B02'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_B3 = ISNULL(MAX(CASE WHEN CL.Code = 'B03'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
   FROM CODELKUP CL WITH (NOLOCK)
   WHERE CL.ListName = 'APMDPAC'



   SELECT O.ExternOrderKey 
     ,   SDESCR     = ISNULL(RTRIM(S.DESCR), '') 
     ,   O.Storerkey 
     ,   SCOLOR     = ISNULL(RTRIM(S.color), '') 
     ,   PickSlipNo = PH.PickSlipNo --
     ,   FPhone1    = ISNULL(RTRIM(F.Phone1), '') 
     ,   FAddress1   = ISNULL(RTRIM(F.Address1), '')  + SPACE(1)  +  ISNULL(RTRIM(F.Address2), '')  + SPACE(1)  +    ISNULL(RTRIM(F.Address3), '')             
     ,   FContact   = ISNULL(RTRIM(F.Contact1), '')
     ,   CAddress   = ISNULL(RTRIM(O.C_Address1), '')  + SPACE(1)  + ISNULL(RTRIM(O.C_Address2), '') + SPACE(1)  +  ISNULL(RTRIM(O.C_Address3), '')  + SPACE(1)  + ISNULL(RTRIM(O.C_Address4), '')                         
     ,   CCityState  = ISNULL(RTRIM(O.C_State), '')  + SPACE(1)  + ISNULL(RTRIM(O.C_City), '')                   
     ,   FUDF01  = ISNULL(RTRIM(F.UserDefine01), '')   --30                       
     ,   FEmail  = ISNULL(RTRIM(F.Email1), '')                 
     ,   CTCube     = CT.[Cube]  --
     ,   Contact1   = ISNULL(RTRIM(O.C_Contact1), '')                 
     ,   Phone1     =  ISNULL(RTRIM(O.C_Phone1), '')                     
     ,   CustEmail  = ISNULL(RTRIM(O.B_Contact1), '')     
     ,   CartonNo   = ISNULL(PD.CartonNo, 0) 
     ,   STBCompany = ISNULL(RTRIM(ST.B_Company), '')
     ,   PD.Sku --
     ,   Qty         = ISNULL(SUM(PD.Qty),0) 
     ,   GrossWGT    = (S.GrossWgt + CT.CartonWeight)
     ,   TTLCTN      =  1
    -- ,   CTCube    = CT.[Cube]
     ,   SUMMPACK    = @c_SummPAck 
     ,   consigneekey  = ISNULL(RTRIM(O.ConsigneeKey), '')
     ,   STAddress     = ISNULL(RTRIM(ST.Address1), '')  + SPACE(1)  +  ISNULL(RTRIM(ST.Address2), '')  + SPACE(1)  +    ISNULL(RTRIM(ST.Address3), '')   
     ,   STPhone1     = ISNULL(RTRIM(ST.Phone1), '')
     ,   STContact    = ISNULL(RTRIM(ST.Contact1), '')
     ,   STEmail      = ISNULL(RTRIM(ST.Email1), '') 
     ,   B1           = @c_B1
     ,   B2           = @c_B2
     ,   B3           = @c_B3
     ,   CCIty        = ISNULL(RTRIM(O.C_City), '')
   FROM ORDERS     O  WITH (NOLOCK)
   JOIN STORER     ST WITH (NOLOCK) ON (ST.StorerKey = O.Storerkey)
   JOIN PACKHEADER PH WITH (NOLOCK) ON (O.Orderkey = PH.Orderkey AND O.Storerkey = PH.Storerkey)
   JOIN PACKDETAIL PD WITH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo)
   JOIN SKU         S WITH (NOLOCK) ON (S.Storerkey = PD.Storerkey)
                                    AND(S.Sku = PD.Sku)
   JOIN  dbo.CARTONIZATION CT WITH (NOLOCK) ON PH.cartongroup=CT.Cartonizationgroup and PH.ctntyp1=CT.CartonType
   JOIN FACILITY F WITH (NOLOCK) ON F.Facility = O.Facility
   JOIN dbo.CODELKUP C WITH (NOLOCK) ON C.LISTNAME='APEDEPCK' AND C.Short = o.DocType AND C.long=o.ConsigneeKey AND UDF01='r_dw_packing_list_107_rdt'
   WHERE  PH.PickSlipNo = @c_PickSlipNo 
   AND PD.CartonNo >= CAST(@c_cartonNoStart AS INT) AND PD.CartonNo <= CAST(@c_cartonNoEnd AS INT)
   GROUP BY O.ExternOrderKey 
        ,   ISNULL(RTRIM(S.DESCR), '') 
        ,   O.Storerkey 
        ,   ISNULL(RTRIM(S.color), '') 
        ,   PH.PickSlipNo
        ,   ISNULL(RTRIM(O.ConsigneeKey), '') 
        ,   ISNULL(RTRIM(F.Phone1), '')
        ,   ISNULL(RTRIM(F.Address1), '')  + SPACE(1)  +  ISNULL(RTRIM(F.Address2), '')  + SPACE(1)  +    ISNULL(RTRIM(F.Address3), '')   
        ,   ISNULL(RTRIM(F.Contact1), '')
        ,   ISNULL(RTRIM(O.C_Address1), '')  + SPACE(1)  + ISNULL(RTRIM(O.C_Address2), '') + SPACE(1)  +  ISNULL(RTRIM(O.C_Address3), '')  + SPACE(1)  + ISNULL(RTRIM(O.C_Address4), '') 
        ,   ISNULL(RTRIM(F.UserDefine01), '')
        ,   ISNULL(RTRIM(F.Email1), '') 
        ,   ISNULL(RTRIM(S.BUSR1), '')
        ,   ISNULL(RTRIM(O.C_Contact1), '')
        ,   ISNULL(RTRIM(O.C_Phone1), '')
        ,   ISNULL(RTRIM(O.C_State), '')  + SPACE(1)  + ISNULL(RTRIM(O.C_City), '')  
        ,   O.Storerkey
        ,   ISNULL(PD.CartonNo, 0)
        ,   PD.Sku
        ,   ISNULL(RTRIM(ST.B_Company), '')
        ,   ISNULL(RTRIM(O.ConsigneeKey), ''),(S.GrossWgt + CT.CartonWeight), CT.[Cube]
        ,   ISNULL(RTRIM(ST.Address1), '')  + SPACE(1)  +  ISNULL(RTRIM(ST.Address2), '')  + SPACE(1)  +    ISNULL(RTRIM(ST.Address3), '')  
        ,   ISNULL(RTRIM(ST.Phone1), ''), ISNULL(RTRIM(ST.Contact1), ''),ISNULL(RTRIM(ST.Email1), '') ,ISNULL(RTRIM(O.C_City), ''),ISNULL(RTRIM(O.B_Contact1), '')  
   ORDER BY PH.PickSlipNo, ISNULL(PD.CartonNo, 0) ,PD.Sku   


   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END

END -- procedure

GO